"""Optional PyTorch implementation of the lightweight 1D-CNN."""

from __future__ import annotations

from typing import Any

import numpy as np


def _torch_components() -> tuple[Any, Any]:
    try:
        import torch
        from torch import nn
    except ImportError as error:
        raise ImportError(
            "1D-CNN training requires PyTorch. Install it with: "
            "python3 -m pip install torch"
        ) from error
    return torch, nn


def _build_network(input_length: int, class_count: int) -> Any:
    """Build a compact CNN that accepts one normalized power trace per row."""
    _, nn = _torch_components()

    class PowerTraceCNN(nn.Module):
        def __init__(self) -> None:
            super().__init__()
            self.features = nn.Sequential(
                nn.Conv1d(1, 16, kernel_size=3, padding=1),
                nn.ReLU(),
                nn.Conv1d(16, 32, kernel_size=3, padding=1),
                nn.ReLU(),
                nn.AdaptiveAvgPool1d(1),
            )
            self.classifier = nn.Linear(32, class_count)

        def forward(self, traces: Any) -> Any:
            return self.classifier(self.features(traces).squeeze(-1))

    return PowerTraceCNN()


def train_1d_cnn(
    x_train: np.ndarray,
    y_train: np.ndarray,
    x_test: np.ndarray,
    y_test: np.ndarray,
    *,
    epochs: int = 20,
    batch_size: int = 32,
    learning_rate: float = 1e-3,
    random_state: int = 42,
    show_epoch_progress: bool = True,
) -> tuple[dict[str, Any], float]:
    """Train the 1D-CNN and return portable state plus test accuracy."""
    if epochs < 1 or batch_size < 1 or learning_rate <= 0:
        raise ValueError("epochs, batch_size, and learning_rate must be positive.")

    torch, nn = _torch_components()
    torch.manual_seed(random_state)
    model = _build_network(x_train.shape[1], len(np.unique(y_train)))
    optimizer = torch.optim.Adam(model.parameters(), lr=learning_rate)
    criterion = nn.CrossEntropyLoss()
    training_data = torch.utils.data.TensorDataset(
        torch.tensor(x_train).unsqueeze(1), torch.tensor(y_train, dtype=torch.long)
    )
    generator = torch.Generator().manual_seed(random_state)
    loader = torch.utils.data.DataLoader(
        training_data, batch_size=batch_size, shuffle=True, generator=generator
    )

    model.train()
    for epoch in range(1, epochs + 1):
        for traces, labels in loader:
            optimizer.zero_grad()
            loss = criterion(model(traces), labels)
            loss.backward()
            optimizer.step()
        if show_epoch_progress:
            print(f"CNN training: epoch {epoch}/{epochs} completed")

    model.eval()
    with torch.no_grad():
        predictions = model(torch.tensor(x_test).unsqueeze(1)).argmax(dim=1).numpy()
    accuracy = float((predictions == y_test).mean())
    state_dict = {name: value.detach().cpu() for name, value in model.state_dict().items()}
    return {
        "architecture": "PowerTraceCNN",
        "input_length": int(x_train.shape[1]),
        "class_count": int(len(np.unique(y_train))),
        "state_dict": state_dict,
    }, accuracy
