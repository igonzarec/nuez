@tool
class_name DistantBlurEffect
extends CompositorEffect
## Desenfoque de distancia como postproceso (Forward+): se aplica a la imagen final, despues de lo transparente, asi que
## agua, nieve, particulas y personajes se desenfocan igual que el terreno. Lo crea y ajusta PlayerCamera (grupo
## Desenfoque de distancia); no hace falta anadirlo a mano. En Compatibility la camara usa distant_blur.gdshader, que
## solo alcanza lo opaco. Shader: shaders/distant_blur_post.glsl.

## Metros desde la camara (a lo largo de la vista) donde empieza el desenfoque.
var focus_distance := 18.0
## Metros extra hasta llegar al desenfoque completo.
var far_transition := 12.0
## Separacion maxima de las muestras, en pixeles de render. 0 = sin desenfoque.
var blur_radius := 3.0

const SHADER_PATH := "res://shaders/distant_blur_post.glsl"
const CONTEXT := &"distant_blur"
const COPY := &"copy"

var _rd: RenderingDevice
var _copy_shader: RID
var _blur_shader: RID
var _copy_pipeline: RID
var _blur_pipeline: RID
var _linear_sampler: RID
var _nearest_sampler: RID

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	RenderingServer.call_on_render_thread(_initialize)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd != null:
		for rid in [_copy_pipeline, _blur_pipeline, _copy_shader, _blur_shader, _linear_sampler, _nearest_sampler]:
			if rid.is_valid():
				_rd.free_rid(rid)

func _initialize() -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return
	var file: RDShaderFile = load(SHADER_PATH)
	_copy_shader = _rd.shader_create_from_spirv(file.get_spirv(&"copy"))
	_blur_shader = _rd.shader_create_from_spirv(file.get_spirv(&"blur"))
	if not _copy_shader.is_valid() or not _blur_shader.is_valid():
		push_error("DistantBlurEffect: no se pudo compilar %s" % SHADER_PATH)
		return
	_copy_pipeline = _rd.compute_pipeline_create(_copy_shader)
	_blur_pipeline = _rd.compute_pipeline_create(_blur_shader)
	var state := RDSamplerState.new()
	state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_nearest_sampler = _rd.sampler_create(state)
	state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	_linear_sampler = _rd.sampler_create(state)

func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if _rd == null or not _blur_pipeline.is_valid() or callback_type != effect_callback_type or blur_radius <= 0.0:
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	var scene_data := render_data.get_render_scene_data()
	if buffers == null or scene_data == null:
		return
	var size := buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return
	# Scratch copy of the colour, owned by the render buffers (freed and recreated by them when the size changes).
	if not buffers.has_texture(CONTEXT, COPY):
		var usage := RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		buffers.create_texture(CONTEXT, COPY, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, usage,
			RenderingDevice.TEXTURE_SAMPLES_1, size, buffers.get_view_count(), 1, true, false)
	var groups := Vector3i((size.x - 1) / 8 + 1, (size.y - 1) / 8 + 1, 1)
	for view in buffers.get_view_count():
		var color := buffers.get_color_layer(view)
		var depth := buffers.get_depth_layer(view)
		var copy := buffers.get_texture_slice(CONTEXT, COPY, view, 0, 1, 1)
		var inverse := scene_data.get_view_projection(view).inverse()
		var push := PackedFloat32Array()
		for column: Vector4 in [inverse.x, inverse.y, inverse.z, inverse.w]:
			push.append_array([column.x, column.y, column.z, column.w])
		push.append_array([size.x, size.y, focus_distance, far_transition, blur_radius, 0.0, 0.0, 0.0])
		var bytes := push.to_byte_array()

		var copy_set := UniformSetCacheRD.get_cache(_copy_shader, 0, [
			_uniform(RenderingDevice.UNIFORM_TYPE_IMAGE, 0, [color]),
			_uniform(RenderingDevice.UNIFORM_TYPE_IMAGE, 1, [copy]),
		])
		var blur_set := UniformSetCacheRD.get_cache(_blur_shader, 0, [
			_uniform(RenderingDevice.UNIFORM_TYPE_IMAGE, 0, [color]),
			_uniform(RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE, 1, [_linear_sampler, copy]),
			_uniform(RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE, 2, [_nearest_sampler, depth]),
		])
		for step in [[_copy_pipeline, copy_set], [_blur_pipeline, blur_set]]:
			var list := _rd.compute_list_begin()
			_rd.compute_list_bind_compute_pipeline(list, step[0])
			_rd.compute_list_bind_uniform_set(list, step[1], 0)
			_rd.compute_list_set_push_constant(list, bytes, bytes.size())
			_rd.compute_list_dispatch(list, groups.x, groups.y, groups.z)
			_rd.compute_list_end()

func _uniform(type: RenderingDevice.UniformType, binding: int, ids: Array) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = type
	uniform.binding = binding
	for id: RID in ids:
		uniform.add_id(id)
	return uniform
