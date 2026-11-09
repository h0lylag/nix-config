{
  hf-repo = "unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL";

  no-mmproj-offload = true;

  ctx-size = 262144;
  cache-type-k = "f16";
  cache-type-v = "f16";
  ubatch-size = 2048;

  temp = 0.6;
  top-p = 0.95;
  top-k = 20;
  min-p = 0.0;
}
