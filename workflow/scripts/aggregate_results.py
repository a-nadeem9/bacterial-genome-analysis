import pandas as pd
import sys
import os
from collections import defaultdict

def robust_read_tsv(file_path):
    """
    A robust function to read TSV files where the header might be a comment.
    """
    with open(file_path, 'r') as f:
        first_line = f.readline().strip()
    
    # Check if the first line is a commented header
    if first_line.startswith('#'):
        # Clean up the header and use it
        headers = first_line.lstrip('#').split('\t')
        df = pd.read_csv(file_path, sep='\t', comment='#', header=None, names=headers)
    else:
        # Assume it's a normal TSV with a header
        df = pd.read_csv(file_path, sep='\t')
        
    return df

# --- Get command line arguments ---
output_excel = sys.argv[1]
input_files = sys.argv[2:]

# --- Data structure to hold our results ---
module_dataframes = defaultdict(list)

# --- Read and categorize all input files ---
for file_path in input_files:
    try:
        if os.path.getsize(file_path) == 0:
            continue

        path_parts = file_path.split(os.sep)
        screening_index = path_parts.index("screening")
        module_name = path_parts[screening_index + 1]
        sample_name = os.path.basename(file_path).split('.')[0]

        if module_name == "mlst":
            df = pd.read_csv(file_path, sep='\t', header=None)
            df.columns = ["File", "Scheme", "ST", "Allele_1", "Allele_2", "Allele_3", "Allele_4", "Allele_5", "Allele_6", "Allele_7"][:len(df.columns)]
        else:
            df = robust_read_tsv(file_path)
        
        df.insert(0, 'Sample', sample_name)
        module_dataframes[module_name].append(df)

    except Exception as e:
        print(f"Skipping file due to error: {file_path} ({e})")

# --- Write the final multi-sheet Excel report ---
with pd.ExcelWriter(output_excel, engine='openpyxl') as writer:
    print("Creating final summary report...")
    
    for module, df_list in module_dataframes.items():
        if not df_list:
            continue
            
        combined_df = pd.concat(df_list, ignore_index=True)
        
        # Write the raw combined data to a sheet
        combined_df.to_excel(writer, sheet_name=f"{module.capitalize()}_Raw_Data", index=False)
        print(f"  - Wrote raw data sheet: {module.capitalize()}_Raw_Data")

        # For AMR, Virulence, and Plasmids, also create a summary matrix
        if module in ["amr", "virulence", "plasmids"]:
            if module == "amr": feature_col = "Best_Hit_ARO"
            elif module == "virulence": feature_col = "GENE"
            elif module == "plasmids": feature_col = "Inc Type(s)" # Note the space in the header
            
            if feature_col in combined_df.columns:
                summary = combined_df.pivot_table(
                    index=feature_col, 
                    columns='Sample', 
                    aggfunc='size', 
                    fill_value=""
                ).replace(1.0, "X")
                summary.to_excel(writer, sheet_name=f"{module.capitalize()}_Summary_Matrix")
                print(f"  - Wrote summary matrix: {module.capitalize()}_Summary_Matrix")

print(f"Successfully created summary report at {output_excel}")
