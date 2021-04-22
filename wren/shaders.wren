var FragmentFbo = "
uniform sampler2D texture;
varying mediump vec2 texcoord;

void main(void) {
  gl_FragColor = texture2D(texture, texcoord);
}
"

var FragmentTile = "
uniform sampler2D texture;
uniform sampler2D map;

varying lowp vec2 texcoord;
varying lowp vec4 vColor;
varying lowp float vIntensity;

uniform lowp vec2 texSize;
uniform lowp vec2 mapSize;
uniform lowp float prio;
uniform lowp vec2 tilesize;
uniform lowp float pixelation;
uniform lowp float time;

void main(void) {
  lowp vec2 inp = texcoord;

  // water wobble
  //inp.x += mod(gl_FragCoord.y, 2.0) * -sin(gl_FragCoord.y / 50.0 + time) + mod(gl_FragCoord.y+1.0, 2.0) * sin(gl_FragCoord.y / 35.0 + time);
  //inp.y += cos(gl_FragCoord.y / 35.0 + time);

  //inp.x *= gl_FragCoord.y / 10.0;

  lowp vec4 tile = texture2D(map, (floor(inp)+0.5) / mapSize);
  tile *= 255.0;
  tile *= 1.0 - floor(mod(tile.z + prio + 0.1, 2.0));

  lowp vec2 oneTile = (texSize / tilesize);

  lowp vec2 offset = ((floor(fract(inp) * tilesize / pixelation) + 0.5) / tilesize * pixelation);
  lowp vec2 uv = (tile.xy + offset) / oneTile;

  lowp vec4 color = texture2D(texture, uv);
  color.a *= 1.0-vColor.a;
  color.rgb = mix(color.rgb, vColor.rgb, vIntensity);
  gl_FragColor = color;
}
"

var Fragment = "
uniform sampler2D uSampler;

varying mediump vec2 texcoord;
varying lowp vec4 vColor;
varying lowp float vIntensity;

void main(void) {
  mediump vec2 uv = mod(texcoord, vec2(1.0)); 
  lowp vec4 color = texture2D(uSampler, texcoord);
  color.a *= 1.0-vColor.a;
  color.rgb = mix(color.rgb, vColor.rgb, vIntensity);
  gl_FragColor = color;
}
"

var VertexFbo = "
attribute vec2 uv;
attribute vec2 position;

varying vec2 texcoord;

void main(void) {
  texcoord = uv; 
  gl_Position = vec4(position, 0.0, 1.0);
}
"

var VertexTile = "
attribute vec4 coordUv;
attribute vec2 scale;
attribute vec2 trans;
attribute float rot;
attribute vec2 prioIntensity;
attribute vec4 color;

uniform vec2 size;
uniform lowp vec2 texSize;
uniform lowp float prio;
uniform lowp vec2 tilesize;

varying vec2 texcoord;
varying vec4 vColor;
varying float vIntensity;

void main(void) {
    vColor = color;
    vIntensity = prioIntensity.y / 255.0;

    vec2 screensize = size / tilesize;
    vec2 uv = (coordUv.zw * screensize) - (screensize / 2.0);// - (size / (tilesize * pixelscale * 2.0));

    float r = -(rot / 10430.0);
    float s = sin(r);
    float c = cos(r);
    float sx = 4096.0 / scale.x;
    float sy = 4096.0 / scale.y;

    float m0 = sx * c;
    float m1 = sx * s;

    float m3 = sy * -s;
    float m4 = sy * c;

    vec2 translation = -(trans / tilesize) + (screensize / 2.0);

    mat3 transformation = mat3(m0, m1, 0.0, m3, m4, 0.0, translation.x, translation.y, 1.0);
    texcoord = (transformation * vec3(uv, 1.0)).xy;
    //  1-l  1-h  2-l  2-h  3-l  3-h  4-l  4-h 
    // 0010 0011 0100 0101 0110 0111 1000 1001
    //    2    3    4    5    6    7    8    9
    float aPrio = floor(prioIntensity.x / 2.0 + 0.1);
    float uPrio = floor((prio+0.1) / 2.0 + 0.1);
    float mult = step(aPrio, uPrio) * step(uPrio, aPrio);
    //float mult = 1.0;
    vec2 xy = mult * coordUv.xy * vec2(1.0, -1.0);
    gl_Position = vec4(xy, 0.0, 1.0);
}
"

var Vertex = "
attribute vec4 coordUv;
attribute vec2 scale;
attribute vec2 trans;
attribute float rot;
attribute vec2 prioIntensity;
attribute vec4 color;

uniform mediump vec2 texSize;

uniform vec2 size;
uniform float prio;

varying vec2 texcoord;
varying vec4 vColor;
varying float vIntensity;

void main(void) {
  vColor = color;
  vIntensity = prioIntensity.y / 255.0;

  vec2 uv = coordUv.zw / texSize;
  texcoord = uv; 

  float r = (rot / 10430.0);
  float s = sin(r);
  float c = cos(r);
  float sx = scale.x / 4096.0;
  float sy = scale.y / 4096.0;
  float sprio = prioIntensity.x;
  float mult = step(prio, sprio) * step(sprio, prio);
  sx *= mult;
  sy *= mult;

  float m0 = sx * c;
  float m1 = sx * s;

  float m3 = sy * -s;
  float m4 = sy * c;
  
  float m6 = trans.x;
  float m7 = trans.y;

  mat3 transformation = mat3(m0, m1, 0.0, m3, m4, 0.0, m6, m7, 1.0);
  //transformation = mat3(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, m6, m7, 1.0);

  vec3 transformed = transformation * vec3(coordUv.xy, 1.0);

  vec2 xy = (transformed.xy / (size / 2.0) - 1.0) * vec2(1.0, -1.0);
  gl_Position = vec4(xy, 0.0, 1.0);
}
"