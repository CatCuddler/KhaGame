#ifdef GL_ES
precision mediump float;
#endif

varying vec2 texCoord;
uniform sampler2D diffuse;

void kore() {
	gl_FragColor = texture2D(diffuse, texCoord);
}
