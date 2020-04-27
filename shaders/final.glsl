/***********************************************************************/
#if defined vsh

noperspective out vec2 texcoord;

void main() {
	texcoord    = gl_Vertex.xy;
	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}

#endif
/***********************************************************************/



/***********************************************************************/
#if defined fsh

#include "lib/debug.glsl"

#!dont-touch
uniform sampler2D colortex0;
#!dont-touch
uniform sampler2D colortex1;
#!dont-touch
uniform sampler2D colortex2;
#!dont-touch
uniform sampler2D colortex3;
#!dont-touch
uniform sampler2D colortex4;
#!dont-touch
uniform sampler2D colortex5;
#!dont-touch
uniform sampler2D depthtex0;
#!dont-touch
uniform sampler2D shadowtex0;

#!dont-touch
const bool colortex2MipmapEnabled = true;
#!dont-touch
const bool colortex3MipmapEnabled = true;
#!dont-touch
const bool colortex4MipmapEnabled = true;
#!dont-touch
const bool colortex5MipmapEnabled = true;

uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float frameTimeCounter;
uniform int frameCounter;
uniform vec2 viewSize;
uniform int hideGUI;

#include "lib/Tonemap.glsl"

noperspective in vec2 texcoord;

#include "lib/exit.glsl"

#include "lib/Text.glsl"

#include "lib/Bloom.fsh"
#include "lib/Random.glsl"

#define MOTION_BLUR

#define MOTION_BLUR_INTENSITY 1.0
#define MAX_MOTION_BLUR_AMOUNT 1.0

#define VARIABLE_MOTION_BLUR_SAMPLES 1
#define VARIABLE_MOTION_BLUR_SAMPLE_COEFFICIENT 1.0
#define MAX_MOTION_BLUR_SAMPLE_COUNT 50
#define CONSTANT_MOTION_BLUR_SAMPLE_COUNT 2

vec3 MotionBlur(vec3 color) {
	float depth = texture(depthtex0, texcoord).x;
	
	vec4 pene;
	pene = vec4(vec3(texcoord, depth) * 2.0 - 1.0, 1.0);
	
	vec4 position = pene;
	
	pene = gbufferProjectionInverse * pene;
	pene = pene / pene.w;
	pene = gbufferModelViewInverse * pene;
	
	pene.xyz = pene.xyz + (cameraPosition - previousCameraPosition) * clamp(length(pene.xyz - gbufferModelViewInverse[3].xyz) / 2.0 - 1.0, 0.0, 1.0);
	pene = gbufferPreviousModelView * pene;
	pene = gbufferPreviousProjection * pene;
	pene = pene / pene.w;
	
	float intensity = MOTION_BLUR_INTENSITY * 0.5;
	float maxVelocity = MAX_MOTION_BLUR_AMOUNT * 0.1;
	
	vec2 velocity = (position.st - pene.st) * intensity; // Screen-space motion vector
	     velocity = clamp(velocity, vec2(-maxVelocity), vec2(maxVelocity));
	
	float sampleCount = length(velocity * viewSize) * VARIABLE_MOTION_BLUR_SAMPLE_COEFFICIENT; // There should be exactly 1 sample for every pixel when the sample coefficient is 1.0
	      sampleCount = floor(clamp(sampleCount, 1, MAX_MOTION_BLUR_SAMPLE_COUNT));
	
	vec2 sampleStep = velocity / sampleCount;
	int hashSeed = int(pow(gl_FragCoord.x, 1.4) * gl_FragCoord.y);
	vec2 offset = sampleStep * WangHash(hashSeed)*0;
	
	for(float i = 1.0; i <= sampleCount; i++) {
		vec2 coord = texcoord + sampleStep * i - offset;
		
		color += texture2D(colortex5, coord).rgb;
	}
	
	return color / max(sampleCount + 1.0, 1.0);
}
#ifndef MOTION_BLUR
	#define MotionBlur(color) (color)
#endif

#define FRAME_ACCUMULATION_COUNTER Off // [On Off]
#define AUTO_EXPOSURE On // [On Off]

void main() {
	vec4 lookup = texture(colortex5, texcoord);
	beni = lookup.a;
	// vec3 color = texture(colortex5, texcoord).rgb;
	vec3 color = lookup.rgb;
	vec3 avgCol = textureLod(colortex5, vec2(0.5), 16).rgb / textureLod(colortex5, vec2(0.5), 16).a;
	float expo = 1.0 / dot(avgCol, vec3(0.2125, 0.7154, 0.0721));
	expo = 1.0;
	if (AUTO_EXPOSURE) {
		expo = pow(1.0 / dot(avgCol, vec3(3.0)), 0.7);
	}
	
	color = MotionBlur(color);
	color *= min(expo, 1000.0);
	color = color / lookup.a;
	color = GetBloom(colortex3, color);
	
	color = Tonemap(color);
	
	gl_FragColor.rgb = color;
	
	if (FRAME_ACCUMULATION_COUNTER) {
		if (hideGUI == 0) {
			vec2 textcoord = texcoord;
			textcoord.x *= viewSize.x / viewSize.y;
			
			vec3 whiteText = vec3(text(textcoord));
			if (texcoord.x < 0.61 && texcoord.y > 0.94) gl_FragColor.rgb *= 0.5;
			gl_FragColor.rgb = mix(gl_FragColor.rgb, vec3(1.0), whiteText);
		}
	}
	
	exit();
}

#endif
/***********************************************************************/
