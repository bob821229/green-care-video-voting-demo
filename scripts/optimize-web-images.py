from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / "src" / "greencare-web" / "public"
POSTERS = PUBLIC / "images" / "posters" / "official"
OPTIMIZED_POSTERS = POSTERS / "optimized"
BANNER = PUBLIC / "assets" / "campaign" / "banner"
RENDERS = ROOT / "artifacts"


def resize_to_width(image: Image.Image, width: int) -> Image.Image:
    height = round(image.height * width / image.width)
    return image.resize((width, height), Image.Resampling.LANCZOS)


def save_webp(image: Image.Image, destination: Path, *, quality: int) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    image.save(destination, "WEBP", quality=quality, method=6)


def optimize_posters() -> None:
    OPTIMIZED_POSTERS.mkdir(parents=True, exist_ok=True)
    for source in sorted(POSTERS.glob("*.jpg")):
        with Image.open(source) as image:
            image = image.convert("RGB")
            for width in (360, 720, 1080):
                save_webp(
                    resize_to_width(image, width),
                    OPTIMIZED_POSTERS / f"{source.stem}-{width}.webp",
                    quality=80,
                )


def optimize_banner_backgrounds() -> None:
    targets = (
        ("hero-desktop-bg.png", "hero-desktop-bg.webp", 3840),
        ("hero-mobile-bg.png", "hero-mobile-bg.webp", 1600),
    )
    for source_name, destination_name, width in targets:
        with Image.open(BANNER / source_name) as image:
            save_webp(resize_to_width(image.convert("RGB"), width), BANNER / destination_name, quality=82)


def optimize_banner_titles() -> None:
    for variant in ("desktop", "mobile"):
        source = RENDERS / f"hero-{variant}-title-render.png"
        with Image.open(source) as image:
            save_webp(image.convert("RGBA"), BANNER / f"hero-{variant}-title.webp", quality=84)


if __name__ == "__main__":
    optimize_posters()
    optimize_banner_backgrounds()
    optimize_banner_titles()
