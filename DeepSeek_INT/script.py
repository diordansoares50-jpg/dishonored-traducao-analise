import re

def fix_translation_file(input_path, output_path):
    # Dishonored usa UTF-16 LE com BOM
    with open(input_path, 'r', encoding='utf-16') as f:
        content = f.read()

    # Regex para capturar o campo e o conteúdo entre aspas que contém quebras de linha
    pattern = r'(m_\w+=")(.*?)("(?:\r?\n|$))'

    def replace_newlines(match):
        prefix = match.group(1)
        body = match.group(2)
        suffix = match.group(3)
        # Substitui a quebra de linha real pelo caractere \n literal
        fixed_body = body.replace('\n', '\\n').replace('\r', '')
        return f"{prefix}{fixed_body}{suffix}"

    # re.DOTALL faz o '.' capturar quebras de linha reais
    fixed_content = re.sub(pattern, replace_newlines, content, flags=re.DOTALL)

    with open(output_path, 'w', encoding='utf-16') as f:
        f.write(fixed_content)

if __name__ == "__main__":
    fix_translation_file('WrittenNotes_twk.int', 'WrittenNotes_twk2.int')