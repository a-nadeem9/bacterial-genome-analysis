def get_screening_inputs_for_report(wildcards):
    """
    Checks the config file and collects the result files from all ACTIVE screening modules.
    """
    input_files = []
    
    if config["screening"]["mlst"]["run"]:
        input_files.extend(expand("results/screening/mlst/{sample}.tsv", sample=ALL_SAMPLES))
    
    if config["screening"]["amr"]["run"]:
        input_files.extend(expand("results/screening/amr/{sample}.txt", sample=ALL_SAMPLES))
        
    if config["screening"]["virulence"]["run"]:
        input_files.extend(expand("results/screening/virulence/{sample}.tsv", sample=ALL_SAMPLES))
        
    if config["screening"]["plasmids"]["run"]:
        input_files.extend(expand("results/screening/plasmids/{sample}.tsv", sample=ALL_SAMPLES))
        
    return input_files


rule aggregate_screening_results:
    input:
        script="workflow/scripts/aggregate_results.py",
        # Use the helper function to dynamically gather all active screening reports
        reports=get_screening_inputs_for_report
    output:
        excel="results/screening_summary_report.xlsx"
    log:
        "logs/aggregate_report.log"
    conda:
        "../envs/reporting.yaml"
    shell:
        # Pass the dynamically gathered reports to the script
        "python {input.script} {output.excel} {input.reports} > {log} 2>&1"
