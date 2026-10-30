# Q8_0 keeps about 31 GiB of experts in RAM, which relic can spare.
{
  hf-repo = "bartowski/Laguna-XS-2.1-GGUF:Q8_0";

  # Only 10 of 40 layers keep a KV cache, at 40 KiB per token in f16, so 160K
  # context is 6.25 GiB, about the most that fits within relic's fit-target
  # margin.
  ctx-size = 163840;
  # Each prompt ubatch copies every RAM-resident expert over PCIe, so larger
  # ubatches process prompts faster.
  ubatch-size = 2048;

  # Poolside's generation_config.json.
  temp = 1.0;
  top-p = 1.0;
  top-k = 20;
  min-p = 0.0;
}
