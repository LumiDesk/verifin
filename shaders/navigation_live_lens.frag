#include <flutter/runtime_effect.glsl>
precision highp float;
// ImageFilter 自动绑定当前帧输入尺寸与纹理，不经 CPU 截图。
uniform vec2 uInputSize;
uniform vec2 uOrigin;
uniform vec2 uSize;
uniform float uActivity;
uniform float uMotion;
uniform sampler2D uSource;
out vec4 fragColor;

float capsule(vec2 p, vec2 size) {
  float r = size.y * 0.5;
  vec2 q = abs(p - size * 0.5) - vec2(max(0.0, size.x * 0.5 - r), 0.0);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
vec4 sampleSource(vec2 uv) {
  uv = clamp(uv, vec2(0.001), vec2(0.999));
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uSource, uv);
}
void main() {
  vec2 uv = FlutterFragCoord().xy / uInputSize;
  vec2 size = uSize * uInputSize;
  vec2 p = (uv - uOrigin) * uInputSize;
  float d = capsule(p, size);
  if (d > 0.0 || uActivity < 0.001) {
    fragColor = sampleSource(uv);
    return;
  }
  vec2 n = normalize(vec2(
    capsule(p + vec2(0.5, 0.0), size) - capsule(p - vec2(0.5, 0.0), size),
    capsule(p + vec2(0.0, 0.5), size) - capsule(p - vec2(0.0, 0.5), size)) + vec2(0.0001));
  float edge = pow(clamp(1.0 + d / max(size.y * 0.18, 1.0), 0.0, 1.0), 2.0);
  vec2 refracted = size * 0.5 + (p - size * 0.5) / (1.0 + uActivity * 0.23);
  refracted -= n * edge * size.y * 0.12 * uActivity;
  refracted.x += uMotion * edge * size.y * 0.025;
  // 边界回到原坐标，避免同一字形在滤镜内外出现突然断层。
  refracted = mix(p, refracted, smoothstep(0.0, max(size.y * 0.24, 1.0), -d));
  vec2 warped = uOrigin + refracted / uInputSize;
  // 同帧 RGBA 一起采样，避免亮暗图标边缘分通道后出现彩色断裂。
  fragColor = sampleSource(warped);
}
