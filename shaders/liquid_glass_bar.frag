#include <flutter/runtime_effect.glsl>
precision highp float;

// 由 BackdropFilter + ImageFilter.shader 驱动：引擎把当前区域底下的页面内容
// （backdrop）作为 uSource 纹理传入，本着色器对每个像素输出最终的玻璃颜色。
// 坐标约定：FlutterFragCoord() 与 uInputSize 同处滤镜坐标空间（本实现借助
// `vsync: this` 的 ClipRRect 让滤镜区域恰为胶囊），uv = fragCoord/uInputSize
// 即归一化采样坐标。不截图、不读回纹理、不采样账目明文。
uniform vec2 uInputSize;
uniform float uDark;      // 1=深色模式 0=浅色
uniform float uMotion;    // 拖动横向动量 -1..1，驱动高光方向偏移
uniform sampler2D uSource;
out vec4 fragColor;

// ---- QWEA0 规格常量 ----
const float kRefractHeight = 60.0;  // 折射参考高度（dp）
const float kBevel = 16.0;          // 斜面宽度（dp）
const float kDispersion = 0.12;     // 色散强度
const float kBlurRadius = 14.0;     // 背景柔化半径（dp，等效 REGULAR 材质）

// 胶囊 SDF：全圆角（radius = 高度一半），等价 QWEA0 cornerRadius=999。
float capsule(vec2 p, vec2 size) {
  float r = size.y * 0.5;
  vec2 q = abs(p - size * 0.5) - vec2(max(0.0, size.x * 0.5 - r), 0.0);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec4 sampleSource(vec2 uv) {
  uv = clamp(uv, vec2(0.001), vec2(0.999));
  return texture(uSource, uv);
}

// 对 backdrop 做轻度柔化作为透光基底（9 tap 高斯）。
vec3 blurSample(vec2 uv) {
  vec2 texel = vec2(kBlurRadius) / uInputSize;
  vec3 acc = vec3(0.0);
  acc += sampleSource(uv).rgb * 0.227027;
  acc += sampleSource(uv + texel * vec2( 1.0,  0.0)).rgb * 0.154821;
  acc += sampleSource(uv + texel * vec2(-1.0,  0.0)).rgb * 0.154821;
  acc += sampleSource(uv + texel * vec2( 0.0,  1.0)).rgb * 0.154821;
  acc += sampleSource(uv + texel * vec2( 0.0, -1.0)).rgb * 0.154821;
  acc += sampleSource(uv + texel * vec2( 1.0,  1.0)).rgb * 0.057307;
  acc += sampleSource(uv + texel * vec2(-1.0,  1.0)).rgb * 0.057307;
  acc += sampleSource(uv + texel * vec2( 1.0, -1.0)).rgb * 0.057307;
  acc += sampleSource(uv + texel * vec2(-1.0, -1.0)).rgb * 0.057307;
  return acc;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uInputSize;
  vec2 size = uInputSize;
  float d = capsule(fragCoord, size);

  // 胶囊外透明（BackdropFilter 已裁剪到圆角矩形，这里兜底）。
  if (d > 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  // 法线（对 SDF 数值求梯度）。
  vec2 n = normalize(vec2(
    capsule(fragCoord + vec2(0.5, 0.0), size) -
        capsule(fragCoord - vec2(0.5, 0.0), size),
    capsule(fragCoord + vec2(0.0, 0.5), size) -
        capsule(fragCoord - vec2(0.0, 0.5), size)) + vec2(0.0001));

  // 斜面权重：越靠边缘折射越强（bevel 16dp 内衰减）。
  float edge = clamp(-d / kBevel, 0.0, 1.0);   // 0=边缘 1=内
  float bevelBand = 1.0 - edge;                 // 0=内 1=边缘
  float refractAmt = pow(bevelBand, 1.6);

  // 折射位移：沿法线把采样坐标向内推形成透镜放大，按高度归一。
  float scale = kRefractHeight / max(size.y, 1.0);
  vec2 refracted = fragCoord - n * refractAmt * kBevel * scale * 1.4;
  vec2 ruv = refracted / uInputSize;

  // 色散：沿法线对 R/B 通道反向偏移（dispersion 0.12），只在斜面区明显。
  vec2 chromaOff = n * refractAmt * kDispersion * kBevel * 0.35 / uInputSize;
  float rC = blurSample(ruv + chromaOff).r;
  vec2 gUv = mix(uv, ruv, refractAmt);
  float gC = blurSample(gUv).g;
  float bC = blurSample(ruv - chromaOff).b;
  vec3 glass = vec3(rC, gC, bC);

  // 染色：深 #000@56% / 浅 #FFF@64%。
  float tintA = uDark > 0.5 ? 0.56 : 0.64;
  vec3 tintRgb = uDark > 0.5 ? vec3(0.0) : vec3(1.0);
  glass = mix(glass, tintRgb, tintA * 0.55);

  // 顶部高光：从顶到 45% 高度竖直渐变淡出，方向随拖动偏移。
  float gloss = pow(clamp(1.0 - fragCoord.y / (size.y * 0.45), 0.0, 1.0), 1.5);
  float glossA = (uDark > 0.5 ? 0.12 : 0.25) * gloss;
  glossA *= (1.0 + uMotion * n.x * 0.4);
  glass += vec3(glossA);

  // 细描边：0.75px 内缩半笔宽。
  float borderBand = smoothstep(0.75, 0.0, -d);
  glass = mix(glass, vec3(1.0), (uDark > 0.5 ? 0.12 : 0.18) * borderBand);

  // 斜面高光：边缘一圈随法线朝上的亮边，强化液态体积感。
  float rim = pow(bevelBand, 3.0) * clamp(n.y * 0.5 + 0.5, 0.0, 1.0);
  glass += vec3(rim * (uDark > 0.5 ? 0.10 : 0.22));

  fragColor = vec4(glass, 1.0);
}
