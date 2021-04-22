attribute vec2 uv;
attribute vec2 position;

varying vec2 texcoord;

void main(void) {
  texcoord = uv; 
  gl_Position = vec4(position, 0.0, 1.0);
}