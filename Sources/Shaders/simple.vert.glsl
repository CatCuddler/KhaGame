#ifdef GL_ES
precision highp float;
#endif

attribute vec3 pos;
attribute vec2 tex;
attribute vec2 nor;
varying vec2 texCoord;
uniform mat4 modelMat;
uniform mat4 viewMat;
uniform mat4 projectionMat;

void kore() {
	texCoord = tex;
	gl_Position = projectionMat * viewMat * modelMat * vec4(pos, 1.0);
}
