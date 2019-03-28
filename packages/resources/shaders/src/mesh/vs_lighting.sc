$input a_position, a_normal
$output v_normal, v_viewdir

#include <bgfx_shader.sh>

uniform vec4 u_eyepos;

void main()
{
    vec3 pos = a_position;
	gl_Position = mul(u_modelViewProj, vec4(pos, 1.0));
	vec4 wpos = mul(u_model[0], vec4(pos, 1.0));
	
	v_viewdir = (u_eyepos - wpos).xyz;	
	v_normal = a_normal;	
}