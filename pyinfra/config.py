"""Пути, общие для всех задач деплоя."""

from pathlib import Path

# config.py лежит рядом с deploy.py, на один уровень ниже корня репозитория.
REPO = Path(__file__).resolve().parents[1]
HOME = Path.home()
