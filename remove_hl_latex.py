import sys
from pathlib import Path


def remove_hl(text: str) -> str:
    result = []
    i = 0

    while i < len(text):
        if text.startswith(r"\hl{", i):
            i += 4  # saute "\hl{"
            depth = 1
            content = []

            while i < len(text) and depth > 0:
                if text[i] == "{":
                    depth += 1
                    content.append(text[i])
                elif text[i] == "}":
                    depth -= 1
                    if depth > 0:
                        content.append(text[i])
                else:
                    content.append(text[i])

                i += 1

            result.append("".join(content))
        else:
            result.append(text[i])
            i += 1

    return "".join(result)


def process_tex_file(input_file: str, output_file: str | None = None):
    input_path = Path(input_file)

    if not input_path.exists():
        raise FileNotFoundError(f"Fichier introuvable : {input_path}")

    if output_file is None:
        output_path = input_path.with_name(
            input_path.stem + "_no_hl" + input_path.suffix
        )
    else:
        output_path = Path(output_file)

    text = input_path.read_text(encoding="utf-8")
    cleaned_text = remove_hl(text)
    output_path.write_text(cleaned_text, encoding="utf-8")

    print(f"Fichier créé : {output_path}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage : python remove_hl.py fichier.tex [sortie.tex]")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) >= 3 else None

    process_tex_file(input_file, output_file)