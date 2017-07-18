#version 450

in vec3 pos;
in vec2 tex;
in vec2 nor;
out vec2 texCoord;
uniform mat4 modelMat;
uniform mat4 viewMat;
uniform mat4 projectionMat;

void kore() {
	texCoord = tex;
	gl_Position = projectionMat * viewMat * modelMat * vec4(pos, 1.0);
}
