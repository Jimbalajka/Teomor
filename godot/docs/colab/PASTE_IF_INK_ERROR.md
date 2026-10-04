# Если снова `_Ink` — вставь ЭТУ ячейку и ▶

Сначала: **Перезапустить сеанс → GPU**.

```python
%pip -q install "setuptools>=70,<82"
%pip -q install --only-binary=:all: "tokenizers>=0.20.3"
%pip -q install -U "pillow>=11" "diffusers>=0.32" "transformers>=4.46,<5" accelerate safetensors huggingface_hub

import typing, PIL.typing as T
if not hasattr(T, "_Ink"):
    T._Ink = typing.Any
    print("patched _Ink")

from PIL import Image, ImageDraw
from diffusers import StableDiffusionPipeline
import torch
print("imports OK", torch.cuda.is_available())
```

Потом ячейку модели из ноутбука (или продолжай ▶3 в обновлённом ipynb).
