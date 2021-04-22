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