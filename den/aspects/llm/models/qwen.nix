{
  hf-repo = "unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL";

  # Only 10 of 40 layers keep a KV cache, so the full context is about 5.4 GiB
  # at f16.
  ctx-size = 262144;

  # Qwen's thinking-mode sampling for coding.
  temp = 0.6;
  top-p = 0.95;
  top-k = 20;
  min-p = 0.0;
}
