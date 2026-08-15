"""Evaluation visualizations for trained power-trace classifiers."""

from __future__ import annotations

from pathlib import Path
from typing import Mapping


def save_evaluation_bar_chart(
    metrics: Mapping[str, Mapping[str, float]], output_path: str | Path
) -> Path:
    """Save a test-set metric comparison chart and return its path.

    Accuracy is shown for every model.  Weighted F1 is shown when it is
    available; the CNN currently reports accuracy only.
    """
    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError as error:
        raise ImportError(
            "Evaluation charts require matplotlib. Install it with: "
            "python3 -m pip install matplotlib"
        ) from error

    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    model_names = list(metrics)
    display_names = [name.replace("_", " ").title() for name in model_names]
    accuracy = [metrics[name]["accuracy"] for name in model_names]
    f1_scores = [metrics[name].get("f1_weighted") for name in model_names]
    positions = list(range(len(model_names)))
    width = 0.36

    figure, axis = plt.subplots(figsize=(9, 5))
    accuracy_bars = axis.bar(
        [position - width / 2 for position in positions],
        accuracy,
        width,
        label="Accuracy",
        color="#2a9d8f",
    )
    f1_bars = axis.bar(
        [position + width / 2 for position in positions],
        [score if score is not None else 0 for score in f1_scores],
        width,
        label="Weighted F1",
        color="#457b9d",
    )
    for bar, score in zip(f1_bars, f1_scores):
        if score is None:
            axis.annotate(
                "N/A",
                (bar.get_x() + bar.get_width() / 2, 0.02),
                ha="center",
                va="bottom",
                fontsize=9,
            )

    for bars in (accuracy_bars, f1_bars):
        for bar in bars:
            if bar.get_height() > 0:
                axis.annotate(
                    f"{bar.get_height():.3f}",
                    (bar.get_x() + bar.get_width() / 2, bar.get_height()),
                    ha="center",
                    va="bottom",
                    fontsize=9,
                    xytext=(0, 3),
                    textcoords="offset points",
                )
    axis.set_title("Test-set model evaluation")
    axis.set_ylabel("Score")
    axis.set_ylim(0, 1.08)
    axis.set_xticks(positions, display_names)
    axis.legend()
    axis.grid(axis="y", alpha=0.25)
    figure.tight_layout()
    figure.savefig(output, dpi=160)
    plt.close(figure)
    return output
