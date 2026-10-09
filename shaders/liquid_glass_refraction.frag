#version 320 es
#include <flutter/runtime_effect.glsl>

precision highp float;

// 转写自 Kyant0/AndroidLiquidGlass（Apache-2.0）的 AGSL 圆角矩形折射，
// 并按本项目的胶囊底栏裁剪为等半径版本：去掉四角半径数组与色散分支，
// 坐标单位改为物理像素，采样坐标按 Flutter 的 ImageFilter.shader 约定取整。
//
// 引擎自动绑定：第一个 vec2 uniform 是输入纹理尺寸（物理像素），
// 第一个 sampler uniform 是输入纹理（即玻璃背后的已绘制内容）。
uniform vec2 u_input_size;
uniform sampler2D u_source;

// 胶囊在输入纹理坐标中的位置与尺寸（物理像素）。
uniform vec2 u_rect_origin;
uniform vec2 u_rect_size;

// 折射参数（物理像素）：u_refraction_height 为受折射影响的边缘厚度，
// u_refraction_amount 为最大采样偏移量，正数表示向胶囊内部取样（放大）。
uniform float u_refraction_height;
uniform float u_refraction_amount;

out vec4 frag_color;

float sd_round_rect(vec2 p, vec2 half_size, float radius) {
  vec2 q = abs(p) - (half_size - vec2(radius));
  return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

vec2 grad_sd_round_rect(vec2 p, vec2 half_size, float radius) {
  vec2 q = abs(p) - (half_size - vec2(radius));
  if (q.x >= 0.0 || q.y >= 0.0) {
    vec2 outward = max(q, vec2(0.0));
    float len = length(outward);
    return len > 0.0 ? sign(p) * (outward / len) : vec2(0.0, -1.0);
  }
  float gx = step(q.y, q.x);
  return sign(p) * vec2(gx, 1.0 - gx);
}

float circle_map(float x) {
  return 1.0 - sqrt(max(1.0 - x * x, 0.0));
}

vec4 sample_source(vec2 p) {
  vec2 uv = clamp(p, vec2(0.0), u_input_size) / u_input_size;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(u_source, uv);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 half_size = u_rect_size * 0.5;
  float radius = min(half_size.x, half_size.y);
  vec2 centered = p - u_rect_origin - half_size;

  float sd = sd_round_rect(centered, half_size, radius);
  if (sd >= 0.0 || u_refraction_height <= 0.0 || u_refraction_amount <= 0.0) {
    frag_color = sample_source(p);
    return;
  }

  float depth = -sd;
  if (depth >= u_refraction_height) {
    frag_color = sample_source(p);
    return;
  }

  float t = clamp(1.0 - depth / u_refraction_height, 0.0, 1.0);
  float amount = circle_map(t) * u_refraction_amount;
  vec2 grad = grad_sd_round_rect(centered, half_size, radius);
  frag_color = sample_source(p - amount * grad);
}
