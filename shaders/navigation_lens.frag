#include <flutter/runtime_effect.glsl>
precision highp float;
uniform vec2 uSize;
uniform vec2 uOrigin;
uniform vec2 uSourceSize;
uniform float uActivity;
uniform float uMotion;
uniform sampler2D uSource;
out vec4 fragColor;

float capsule(vec2 p) {
  float r = uSize.y * 0.5;
  vec2 q = abs(p - uSize * 0.5) - vec2(max(0.0, uSize.x * 0.5 - r), 0.0);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float d = capsule(p);
  float mask = 1.0 - smoothstep(-0.7, 0.5, d);
  vec2 n = normalize(vec2(capsule(p + vec2(0.5, 0.0)) - capsule(p - vec2(0.5, 0.0)),
                          capsule(p + vec2(0.0, 0.5)) - capsule(p - vec2(0.0, 0.5))) + vec2(0.0001));
  float edge = pow(clamp(1.0 + d / 10.0, 0.0, 1.0), 2.0);
  float magnification = 1.0 + uActivity * 0.23;
  vec2 refracted = uSize * 0.5 + (p - uSize * 0.5) / magnification;
  refracted -= n * edge * 9.0 * uActivity;
  refracted.x += uMotion * edge * 2.0;
  vec2 uv = (uOrigin + refracted) / uSourceSize;
  vec2 split = n * edge * 1.1 * uActivity / uSourceSize;
  vec4 c = texture(uSource, clamp(uv, vec2(0.001), vec2(0.999)));
  vec4 r = texture(uSource, clamp(uv + split, vec2(0.001), vec2(0.999)));
  vec4 b = texture(uSource, clamp(uv - split, vec2(0.001), vec2(0.999)));
  fragColor = vec4(r.r, c.g, b.b, max(c.a, max(r.a, b.a))) * mask;
}
