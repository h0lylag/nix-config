{
  # Hugging Face rejects the custom Q4_K_P quant as a -hf tag, so the file is
  # named directly.
  hf-repo = "HauhauCS/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive";
  hf-file = "Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf";
  no-mmproj = true;

  # Only 10 of 40 layers keep a KV cache, so the full context is about 5.4 GiB
  # at f16.
  ctx-size = 262144;

  # Qwen's thinking-mode sampling for coding.
  temp = 0.6;
  top-p = 0.95;
  top-k = 20;
  min-p = 0.0;
}
