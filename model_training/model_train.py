"""Training entry point for reusable ML workflows."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from sklearn.base import clone
from sklearn.metrics import accuracy_score

from .utils import (
    build_default_model,
    load_csv_data,
    prepare_train_test_split,
    save_pickle,
    split_features_and_target,
)
 

def train_model(
    csv_path: str | Path,
    target_column: str,
    output_path: str | Path = "artifacts/trained_model.pkl",
    model: Any | None = None,
    test_size: float = 0.2,
    random_state: int = 42,
   
) -> dict[str, Any]:
    """
    Train a model using tabular CSV data and save it as a pickle file.

    The supplied model should follow the scikit-learn API (`fit`, `predict`).
    If no model is supplied, a RandomForestClassifier baseline is used.
    """
    data = load_csv_data(csv_path)
    features, target = split_features_and_target(data, target_column)
    x_train, x_test, y_train, y_test = prepare_train_test_split(
        features,
        target,
        test_size=test_size,
        random_state=random_state,
    )

    estimator = clone(model) if model is not None else build_default_model(random_state)
    estimator.fit(x_train, y_train)

    predictions = estimator.predict(x_test)
    accuracy = accuracy_score(y_test, predictions)
    saved_model_path = save_pickle(estimator, output_path)

    return {
        "model": estimator,
        "model_path": str(saved_model_path),
        "accuracy": accuracy,
        "train_size": len(x_train),
        "test_size": len(x_test),
    }
