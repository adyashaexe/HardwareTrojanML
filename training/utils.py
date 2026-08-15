"""Data loading, validation, preprocessing, and persistence helpers."""

from __future__ import annotations

import json
import pickle
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder, StandardScaler


def load_csv_data(csv_path: str | Path) -> pd.DataFrame:
    """Load a CSV file into a DataFrame."""
    return pd.read_csv(csv_path)


def load_huggingface_data(
    dataset_id: str,
    split: str = "train",
    revision: str | None = None,
) -> pd.DataFrame:
    """Load one tabular dataset split from the Hugging Face Hub."""
    try:
        from datasets import load_dataset
    except ImportError as error:
        raise ImportError(
            "Hugging Face support requires 'datasets'. Install it with: "
            "python3 -m pip install datasets"
        ) from error

    return load_dataset(dataset_id, split=split, revision=revision).to_pandas()


def power_trace_features(
    data: pd.DataFrame,
    target_column: str,
    trace_column: str | None = None,
) -> tuple[np.ndarray, pd.Series]:
    """Return a finite feature matrix and its clean/Trojan label vector.

    ``trace_column`` should contain one fixed-length numeric list per row. If it
    is omitted, every numeric column except the target becomes a feature.
    """
    if data.empty:
        raise ValueError("The dataset is empty.")
    if target_column not in data.columns:
        raise ValueError(f"Target column '{target_column}' was not found.")

    target = data[target_column]
    if target.isna().any():
        raise ValueError("The target column contains missing values.")
    if target.nunique() < 2:
        raise ValueError("At least two classes are required for classification.")

    if trace_column is None:
        numeric_features = data.drop(columns=[target_column]).select_dtypes(include="number")
        if numeric_features.empty:
            raise ValueError(
                "No numeric features found. Set trace_column to the power-trace column."
            )
        matrix = numeric_features.to_numpy(dtype=np.float32)
    else:
        if trace_column not in data.columns:
            raise ValueError(f"Trace column '{trace_column}' was not found.")
        try:
            traces = [
                json.loads(trace) if isinstance(trace, str) else trace
                for trace in data[trace_column]
            ]
            matrix = np.asarray(traces, dtype=np.float32)
        except (TypeError, ValueError) as error:
            raise ValueError("Each power trace must contain only numeric samples.") from error
        if matrix.ndim != 2 or matrix.shape[1] == 0:
            raise ValueError("Power traces must have the same non-zero length.")

    if not np.isfinite(matrix).all():
        raise ValueError("Features contain missing or non-finite values.")
    return matrix, target.reset_index(drop=True)


def prepare_model_inputs(
    features: np.ndarray,
    target: pd.Series,
    test_size: float = 0.2,
    random_state: int = 42,
) -> dict[str, object]:
    """Create one stratified split and one fitted scaler for every model."""
    if not 0 < test_size < 1:
        raise ValueError("test_size must be a number between 0 and 1.")

    class_counts = target.value_counts()
    if class_counts.min() < 2:
        raise ValueError("Every class needs at least two samples for a stratified split.")

    x_train, x_test, y_train, y_test = train_test_split(
        features,
        target.to_numpy(),
        test_size=test_size,
        random_state=random_state,
        stratify=target.to_numpy(),
    )
    label_encoder = LabelEncoder().fit(y_train)
    try:
        y_train_encoded = label_encoder.transform(y_train)
        y_test_encoded = label_encoder.transform(y_test)
    except ValueError as error:
        raise ValueError("All classes must be represented in the training split.") from error

    scaler = StandardScaler().fit(x_train)
    return {
        "x_train": scaler.transform(x_train).astype(np.float32),
        "x_test": scaler.transform(x_test).astype(np.float32),
        "y_train": y_train_encoded,
        "y_test": y_test_encoded,
        "scaler": scaler,
        "label_encoder": label_encoder,
    }


def save_pickle(model_bundle: object, output_path: str | Path) -> Path:
    """Persist a fitted model bundle to a pickle file."""
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as file:
        pickle.dump(model_bundle, file)
    return output
