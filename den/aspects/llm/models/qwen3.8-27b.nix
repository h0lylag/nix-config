{
  hf-repo = "unsloth/Qwen3.8-27B-GGUF:UD-IQ4_XS";

  no-mmproj-offload = true;

  ctx-size = 73728;
  cache-type-k = "f16";
  cache-type-v = "f16";

  temp = 1.0;
  top-p = 0.95;
  top-k = 20;
  min-p = 0.0;
}
