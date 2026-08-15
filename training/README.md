# Hardware Trojan power-trace model training

This package trains and evaluates three classifiers on exactly the same
stratified train/test split:

- Random Forest
- RBF-kernel SVM
- lightweight 1D-CNN

The input is standardized once using statistics learned only from the training
partition. This prevents test-data leakage and gives the SVM and CNN comparable
normalized inputs; the same transformed input is also used for Random Forest.

## Dataset format

Each row is one FPGA power measurement and needs a binary target column (for
example `label` with `clean` and `trojan`). Use either a fixed-length sequence
column such as `power_trace`, or one numeric CSV column per sample.

```text
label,power_trace
clean,"[0.12, 0.13, 0.11, ...]"
trojan,"[0.44, 0.41, 0.48, ...]"
```

When CSV trace cells are JSON-like strings, convert them to lists before calling
`train_three_models`; a Hugging Face `Sequence` column already loads as lists.

## Install

```bash
python3 -m pip install -r requirements.txt
```

## Train from Hugging Face

```python
from model_training import train_models_from_huggingface

result = train_models_from_huggingface(
    dataset_id="your-user/fpga-power-traces",
    target_column="label",
    trace_column="power_trace",
    cnn_epochs=20,
)
print(result["model_path"])
print(result["evaluation_plot_path"])
print(result["metrics"])
```

## Train from CSV

```python
from model_training import train_models_from_csv

result = train_models_from_csv(
    "data/power_traces.csv",
    target_column="label",
    output_path="artifacts/hardware_trojan_models.pkl",
)
```

The output pickle defaults to `artifacts/hardware_trojan_models.pkl`. Training
also writes `artifacts/hardware_trojan_models.evaluation.png`, a bar chart that
compares test-set accuracy and weighted F1 scores. Set `evaluation_plot_path`
when calling a training function to choose another chart location. The pickle stores
the fitted scaler, label encoder, SVM, Random Forest, 1D-CNN architecture
configuration/state dictionary, and metrics. Only load pickle files you trust.

During CNN training, each completed epoch is printed as
`CNN training: epoch 3/20 completed`. Set `show_epoch_progress=False` to silence
these messages.
