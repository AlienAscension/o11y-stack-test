#!/usr/bin/env python3
"""
CSV zu LaTeX Konverter für LGTM Baseline Statistiken

Verwendung:
    python3 csv-to-latex.py baseline-idle.csv
    python3 csv-to-latex.py baseline-idle.csv baseline-load.csv  # Vergleich
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
    # Entferne Hash am Ende (z.B. grafana-586f5d7949-5mstz -> grafana)
    if pod_name.count('-') >= 2:
        parts = pod_name.rsplit('-', 2)
        return parts[0]
    return pod_name


def csv_to_latex_table(csv_file, title="LGTM Stack Baseline", label="tab:baseline"):
    """Konvertiert CSV zu LaTeX-Tabelle"""
    
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
    
    # Clean quotes from headers and values
    cleaned_rows = []
    for row in rows:
        cleaned_row = {}
        for key, value in row.items():
            clean_key = key.strip('"')
            clean_value = value.strip('"') if isinstance(value, str) else value
            cleaned_row[clean_key] = clean_value
        cleaned_rows.append(cleaned_row)
    
    rows = cleaned_rows
    headers = list(rows[0].keys())
    
    # LaTeX-Tabelle generieren
    latex = []
    latex.append("\\begin{table}[h!]")
    latex.append("  \\begin{center}")
    
    # Spalten-Definitionen: l für erste Spalte (Pod), S für Zahlen (siunitx alignment)
    num_cols = len(headers)
    col_spec = "l|" + "|".join(["S"] * (num_cols - 1))
    latex.append(f"    \\begin{{tabular}}{{{col_spec}}}")
    
    # Header-Zeile mit \textbf
    header_parts = [f"\\textbf{{{headers[0]}}}"]  # Erste Spalte (Pod)
    for header in headers[1:]:
        header_parts.append(f"\\textbf{{{header}}}")
    latex.append("      " + " & ".join(header_parts) + "\\\\")
    latex.append("      \\hline")
    
    # Daten-Zeilen
    for row in rows:
        values = []
        for i, header in enumerate(headers):
            value = row[header]
            if i == 0:  # Pod-Name (erste Spalte)
                values.append(shorten_pod_name(value))
            else:  # Numerische Werte
                values.append(round_value(value))
        
        latex.append("      " + " & ".join(values) + "\\\\")
    
    latex.append("    \\end{tabular}")
    latex.append("  \\end{center}")
    latex.append(f"  \\caption{{{title}}}")
    latex.append(f"  \\label{{{label}}}")
    latex.append("\\end{table}")
    
    return "\n".join(latex)


def csv_to_latex_comparison(csv_idle, csv_load):
    """Erstellt Vergleichstabelle: Idle vs Load"""
    
    # Beide CSV lesen (Tab-separated)
    with open(csv_idle, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter='\t')
        idle_rows = list(reader)
    
    # Clean idle data
    idle_data = {}
    for row in idle_rows:
        cleaned = {}
        for key, value in row.items():
            clean_key = key.strip('"')
            clean_value = value.strip('"') if isinstance(value, str) else value
            cleaned[clean_key] = clean_value
        pod_name = cleaned.get('Pod', '')
        if pod_name:
            idle_data[pod_name] = cleaned
    
    with open(csv_load, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter='\t')
        load_rows = list(reader)
    
    # Clean load data
    load_data = {}
    for row in load_rows:
        cleaned = {}
        for key, value in row.items():
            clean_key = key.strip('"')
            clean_value = value.strip('"') if isinstance(value, str) else value
            cleaned[clean_key] = clean_value
        pod_name = cleaned.get('Pod', '')
        if pod_name:
            load_data[pod_name] = cleaned
    
    # Gemeinsame Pods
    common_pods = sorted(set(idle_data.keys()) & set(load_data.keys()))
    
    latex = []
    latex.append("\\begin{table}[h!]")
    latex.append("  \\begin{center}")
    latex.append("    \\begin{tabular}{l|S|S|S|S|S|S}")
    latex.append("      \\textbf{Pod} & \\multicolumn{3}{c|}{\\textbf{Idle}} & \\multicolumn{3}{c}{\\textbf{Load}} \\\\")
    latex.append("      \\hline")
    latex.append("      & \\textbf{CPU Ø} & \\textbf{Mem Ø} & \\textbf{Disk W Ø} & \\textbf{CPU Ø} & \\textbf{Mem Ø} & \\textbf{Disk W Ø} \\\\")
    latex.append("      & \\textbf{(m)} & \\textbf{(MiB)} & \\textbf{(MiB/s)} & \\textbf{(m)} & \\textbf{(MiB)} & \\textbf{(MiB/s)} \\\\")
    latex.append("      \\hline")
    
    for pod in common_pods:
        pod_short = shorten_pod_name(pod)
        idle_row = idle_data[pod]
        load_row = load_data[pod]
        
        values = [
            pod_short,
            round_value(idle_row.get('CPU Ø (m)', '0')),
            round_value(idle_row.get('Mem Ø (MiB)', '0')),
            round_value(idle_row.get('Disk Write Ø (MiB/s)', '0')),
            round_value(load_row.get('CPU Ø (m)', '0')),
            round_value(load_row.get('Mem Ø (MiB)', '0')),
            round_value(load_row.get('Disk Write Ø (MiB/s)', '0')),
        ]
        
        latex.append("      " + " & ".join(values) + "\\\\")
    
    latex.append("    \\end{tabular}")
    latex.append("  \\end{center}")
    latex.append("  \\caption{LGTM Stack Baseline Vergleich: Idle vs. Load}")
    latex.append("  \\label{tab:baseline-comparison}")
    latex.append("\\end{table}")
    
    return "\n".join(latex)


def main():
    if len(sys.argv) < 2:
        print("Verwendung:")
        print("  python3 csv-to-latex.py <csv-file>")
        print("  python3 csv-to-latex.py <idle.csv> <load.csv>  # Vergleich")
        print()
        print("Beispiel:")
        print("  python3 csv-to-latex.py baseline-idle.csv")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    output_file = Path(csv_file).stem + ".tex"
    
    if len(sys.argv) == 3:
        # Vergleichstabelle
        csv_idle = sys.argv[1]
        csv_load = sys.argv[2]
        
        print(f"📊 Erstelle Vergleichstabelle aus:")
        print(f"   Idle: {csv_idle}")
        print(f"   Load: {csv_load}")
        
        latex_code = csv_to_latex_comparison(csv_idle, csv_load)
        output_file = "baseline-comparison.tex"
    else:
        # Einzelne Tabelle
        print(f"📊 Konvertiere: {csv_file}")
        
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
        
        latex_code = csv_to_latex_table(csv_file, title, label)
    
    if latex_code:
        # In .tex Datei schreiben
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(latex_code)
        
        print(f"✅ LaTeX-Tabelle erstellt: {output_file}")
        print()
        print("📋 Kopiere in deine LaTeX-Datei oder verwende:")
        print(f"   \\input{{{output_file}}}")
        print()
        print("📦 Benötigte LaTeX-Pakete:")
        print("   \\usepackage{siunitx}   % für S Spalten (Zahlen-Alignment)")
        print("   \\usepackage{booktabs}  % für schönere Linien (optional)")
        print()
        print("─" * 60)
        print("Vorschau:")
        print("─" * 60)
        print(latex_code)
        print("─" * 60)


if __name__ == "__main__":
    main()
