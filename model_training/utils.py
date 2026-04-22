"""Utility helpers for model training workflows."""

from __future__ import annotations

import pickle
from pathlib import Path
from typing import Tuple

import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split


def load_csv_data(csv_path: str | Path) -> pd.DataFrame:
    """Load a CSV file into a pandas DataFrame."""
    return pd.read_csv(csv_path)


def split_features_and_target(
    data: pd.DataFrame,
    target_column: str,
) -> Tuple[pd.DataFrame, pd.Series]:
    """Split the full dataset into features and target."""
    if target_column not in data.columns:
        raise ValueError(f"Target column '{target_column}' was not found in the dataset.")

    features = data.drop(columns=[target_column])
    target = data[target_column]
    return features, target


def build_default_model(random_state: int = 42) -> RandomForestClassifier:
    """Create a default baseline model."""
    return RandomForestClassifier(
        n_estimators=200,
        random_state=random_state,
    )


def prepare_train_test_split(
    features: pd.DataFrame,
    target: pd.Series,
    test_size: float = 0.2,
    random_state: int = 42,
):
    """Prepare train/test partitions."""
    return train_test_split(
        features,
        target,
        test_size=test_size,
        random_state=random_state,
        stratify=target if target.nunique() > 1 else None,
    )


def save_pickle(model, output_path: str | Path) -> Path:
    """Persist a trained model to a pickle file."""
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    with output.open("wb") as file:
        pickle.dump(model, file)

    return output
