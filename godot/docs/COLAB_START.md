# Colab с нуля — Теомор

## Открыть готовый ноутбук

https://colab.research.google.com/github/Jimbalajka/Teomor/blob/main/godot/docs/colab/teomor_seamless.ipynb

1. **Среда выполнения → Сменить → GPU**
2. ▶ ячейки сверху вниз
3. Скачать `teomor_tile_seamless.png` слева в Files

## Если уже сломал сессию (ошибки `_Ink` / `ImageDraw` / `tokenizers`)

Причина: Colab на **Python 3.13** + ручной `pip uninstall pillow`.

1. **Среда выполнения → Перезапустить сеанс**
2. Снова **GPU**
3. Открой ноутбук по ссылке выше **заново** (не старую вкладку)
4. ▶1 → ▶2 → ▶3

**Нельзя:** `pip uninstall pillow` — после этого `ImageDraw` умирает.

### Аварийная ячейка (вставь первой после рестарта)

```python
%pip -q install -U pip setuptools wheel
%pip -q install --only-binary=:all: "tokenizers>=0.20.3"
%pip -q install -U "pillow>=11.0.0" "diffusers>=0.32.0" "transformers>=4.46.0" "accelerate" "safetensors" "huggingface_hub"
```

Потом ▶ загрузку модели из ноутбука.

Если `tokenizers` снова ругается на building wheel — пришли скрин; тогда уйдём на Kaggle (там Python 3.10) или web-генератор.

Промпты слотов: [AI_ASSETS.md](AI_ASSETS.md).
