#version 450

in vec2 texCoord;
uniform sampler2D diffuse;
out vec4 FragColor;

void kore() {
	FragColor = texture(diffuse, texCoord);
}
