"""Train SVM, Random Forest, and 1D-CNN power-trace classifiers together."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, f1_score
from sklearn.svm import SVC

from .cnn import train_1d_cnn
from .evaluation import save_evaluation_bar_chart
from .utils import (
    load_csv_data,
    load_huggingface_data,
    power_trace_features,
    prepare_model_inputs,
    save_pickle,
)


def _metrics(y_true: np.ndarray, predictions: np.ndarray) -> dict[str, float]:
    return {
        "accuracy": float(accuracy_score(y_true, predictions)),
        "f1_weighted": float(f1_score(y_true, predictions, average="weighted", zero_division=0)),
    }


def train_three_models(
    data: pd.DataFrame,
    target_column: str,
    output_path: str | Path = "artifacts/hardware_trojan_models.pkl",
    *,
    trace_column: str | None = None,
    test_size: float = 0.2,
    random_state: int = 42,
    cnn_epochs: int = 20,
    cnn_batch_size: int = 32,
    cnn_learning_rate: float = 1e-3,
    show_epoch_progress: bool = True,
    evaluation_plot_path: str | Path | None = None,
) -> dict[str, Any]:
    """Train SVM, Random Forest, and 1D-CNN using one shared data split.

    The resulting pickle contains fitted preprocessing, SVM, Random Forest, and
    the CNN state dictionary. Its metrics are all calculated on the same test
    data, making the comparison fair.
    """
    features, target = power_trace_features(data, target_column, trace_column)
    prepared = prepare_model_inputs(features, target, test_size, random_state)
    x_train = prepared["x_train"]
    x_test = prepared["x_test"]
    y_train = prepared["y_train"]
    y_test = prepared["y_test"]

    random_forest = RandomForestClassifier(
        n_estimators=300,
        random_state=random_state,
        n_jobs=-1,
        class_weight="balanced",
    ).fit(x_train, y_train)
    svm = SVC(
        kernel="rbf",
        C=1.0,
        gamma="scale",
        class_weight="balanced",
        probability=True,
        random_state=random_state,
    ).fit(x_train, y_train)
    cnn_artifact, cnn_accuracy = train_1d_cnn(
        x_train,
        y_train,
        x_test,
        y_test,
        epochs=cnn_epochs,
        batch_size=cnn_batch_size,
        learning_rate=cnn_learning_rate,
        random_state=random_state,
        show_epoch_progress=show_epoch_progress,
    )

    model_bundle = {
        "format_version": 1,
        "feature_count": int(features.shape[1]),
        "target_column": target_column,
        "trace_column": trace_column,
        "scaler": prepared["scaler"],
        "label_encoder": prepared["label_encoder"],
        "models": {
            "random_forest": random_forest,
            "svm": svm,
            "cnn_1d": cnn_artifact,
        },
        "metrics": {
            "random_forest": _metrics(y_test, random_forest.predict(x_test)),
            "svm": _metrics(y_test, svm.predict(x_test)),
            "cnn_1d": {"accuracy": cnn_accuracy},
        },
    }
    saved_path = save_pickle(model_bundle, output_path)
    plot_path = (
        Path(evaluation_plot_path)
        if evaluation_plot_path is not None
        else saved_path.with_suffix(".evaluation.png")
    )
    saved_plot_path = save_evaluation_bar_chart(model_bundle["metrics"], plot_path)
    return {
        "model_path": str(saved_path),
        "evaluation_plot_path": str(saved_plot_path),
        "metrics": model_bundle["metrics"],
        "train_size": int(len(x_train)),
        "test_size": int(len(x_test)),
    }


def train_models_from_csv(
    csv_path: str | Path,
    target_column: str,
    output_path: str | Path = "artifacts/hardware_trojan_models.pkl",
    **kwargs: Any,
) -> dict[str, Any]:
    """Load a CSV file and train all three models."""
    return train_three_models(
        load_csv_data(csv_path), target_column, output_path=output_path, **kwargs
    )


def train_models_from_huggingface(
    dataset_id: str,
    target_column: str,
    output_path: str | Path = "artifacts/hardware_trojan_models.pkl",
    *,
    split: str = "train",
    revision: str | None = None,
    **kwargs: Any,
) -> dict[str, Any]:
    """Load a labelled Hugging Face dataset and train all three models."""
    result = train_three_models(
        load_huggingface_data(dataset_id, split=split, revision=revision),
        target_column,
        output_path=output_path,
        **kwargs,
    )
    result.update({"dataset_id": dataset_id, "split": split, "revision": revision})
    return result
