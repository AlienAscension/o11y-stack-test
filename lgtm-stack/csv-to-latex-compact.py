#!/usr/bin/env python3
"""
CSV zu LaTeX Konverter (Kompakte Version) für LGTM Baseline Statistiken

Zeigt nur die wichtigsten Metriken: CPU Ø, Mem Ø, Disk Write Ø, Net TX Ø
"""

import sys
import csv
from pathlib import Path


def round_value(value):
    """Rundet Werte sinnvoll für LaTeX"""
    try:
        num = float(value)
        if num < 0.01:
            return "< 0.01"
        elif num < 1:
            return f"{num:.2f}"
        elif num < 10:
            return f"{num:.1f}"
        else:
            return f"{num:.0f}"
    except (ValueError, TypeError):
        return value


def shorten_pod_name(pod_name):
    """Kürzt lange Pod-Namen für bessere LaTeX-Darstellung"""
    if pod_name.count('-') >= 2:
        parts = pod_name.rsplit('-', 2)
        return parts[0]
    return pod_name


def csv_to_latex_compact(csv_file, title="LGTM Stack Baseline", label="tab:baseline"):
    """Konvertiert CSV zu kompakter LaTeX-Tabelle (nur wichtigste Metriken)"""
    
    csv_path = Path(csv_file)
    if not csv_path.exists():
        print(f"❌ Fehler: Datei nicht gefunden: {csv_file}")
        return None
    
    # CSV lesen (Tab-separated)
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter='\t')
        rows = list(reader)
    
    if not rows:
        print(f"❌ Fehler: CSV ist leer: {csv_file}")
        return None
    
    # Clean quotes
    cleaned_rows = []
    for row in rows:
        cleaned_row = {}
        for key, value in row.items():
            clean_key = key.strip('"')
            clean_value = value.strip('"') if isinstance(value, str) else value
            cleaned_row[clean_key] = clean_value
        cleaned_rows.append(cleaned_row)
    
    rows = cleaned_rows
    
    # Wichtigste Spalten auswählen
    important_cols = ['Pod', 'CPU Ø (m)', 'Mem Ø (MiB)', 'Disk Write Ø (MiB/s)', 'Net TX Ø (MiB/s)']
    
    latex = []
    latex.append("\\begin{table}[h!]")
    latex.append("  \\begin{center}")
    latex.append("    \\begin{tabular}{l|S|S|S|S}")
    latex.append("      \\textbf{Komponente} & \\textbf{CPU Ø} & \\textbf{Mem Ø} & \\textbf{Disk W Ø} & \\textbf{Net TX Ø}\\\\")
    latex.append("      & \\textbf{(m)} & \\textbf{(MiB)} & \\textbf{(MiB/s)} & \\textbf{(MiB/s)}\\\\")
    latex.append("      \\hline")
    
    # Daten-Zeilen
    for row in rows:
        pod_short = shorten_pod_name(row['Pod'])
        values = [
            pod_short,
            round_value(row.get('CPU Ø (m)', '0')),
            round_value(row.get('Mem Ø (MiB)', '0')),
            round_value(row.get('Disk Write Ø (MiB/s)', '0')),
            round_value(row.get('Net TX Ø (MiB/s)', '0')),
        ]
        latex.append("      " + " & ".join(values) + "\\\\")
    
    latex.append("    \\end{tabular}")
    latex.append("  \\end{center}")
    latex.append(f"  \\caption{{{title}}}")
    latex.append(f"  \\label{{{label}}}")
    latex.append("\\end{table}")
    
    return "\n".join(latex)


def main():
    if len(sys.argv) < 2:
        print("Verwendung:")
        print("  python3 csv-to-latex-compact.py <csv-file>")
        print()
        print("Beispiel:")
        print("  python3 csv-to-latex-compact.py baseline-30minutes-components-utf8.csv")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    output_file = Path(csv_file).stem + "-compact.tex"
    
    print(f"📊 Konvertiere (kompakt): {csv_file}")
    
    # Erkenne ob Idle oder Load aus Dateinamen
    if "idle" in csv_file.lower():
        title = "LGTM Stack Baseline -- Idle (ohne Last)"
        label = "tab:baseline-idle"
    elif "load" in csv_file.lower():
        title = "LGTM Stack Baseline -- Load (mit OTEL Demo)"
        label = "tab:baseline-load"
    else:
        title = "LGTM Stack Baseline"
        label = "tab:baseline"
    
    latex_code = csv_to_latex_compact(csv_file, title, label)
    
    if latex_code:
        # In .tex Datei schreiben
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(latex_code)
        
        print(f"✅ LaTeX-Tabelle erstellt: {output_file}")
        print()
        print("📋 Kopiere in deine LaTeX-Datei oder verwende:")
        print(f"   \\input{{{output_file}}}")
        print()
        print("📦 Benötigtes LaTeX-Paket:")
        print("   \\usepackage{siunitx}   % für S Spalten (Zahlen-Alignment)")
        print()
        print("─" * 60)
        print("Vorschau:")
        print("─" * 60)
        print(latex_code)
        print("─" * 60)


if __name__ == "__main__":
    main()
