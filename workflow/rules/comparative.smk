# --- Helper function to build the final list of GFFs for Panaroo ---
# FIX: Added 'wildcards' as an argument to the function
def get_panaroo_inputs(wildcards):
    # Start with the GFFs from the filtered sample list (excluding blacklisted samples)
    gff_files = expand("results/annotation/{sample}/{sample}.gff3", sample=SAMPLES_FOR_COMPARATIVE)
    
    # Check if an outgroup is specified in the config
    outgroup_gff = config["comparative"]["outgroup"]["gff"]
    if outgroup_gff and outgroup_gff.strip(): # Check if the path is not empty
        gff_files.append(outgroup_gff)
        
    return gff_files

# --- Main Rules ---

rule run_panaroo:
    input:
        # Use the helper function to get the dynamic list of inputs
        gffs=get_panaroo_inputs
    output:
        alignment="results/comparative/panaroo/core_gene_alignment.aln",
        graph="results/comparative/panaroo/final_graph.gml"
    params:
        outdir="results/comparative/panaroo",
        extra=config["comparative"]["panaroo"]["extra"]
    log:
        "logs/panaroo.log"
    threads:
        config["comparative"]["panaroo"]["threads"]
    conda:
        "../envs/comparative.yaml"
    shell:
        "panaroo "
        "-i {input.gffs} "
        "-o {params.outdir} "
        "--threads {threads} "
        "{params.extra} "
        "--remove-invalid-genes > {log} 2>&1"

rule run_iqtree:
    input:
        alignment="results/comparative/panaroo/core_gene_alignment.aln"
    output:
        treefile="results/comparative/iqtree/core_genome.treefile"
    params:
        prefix="results/comparative/iqtree/core_genome",
        extra=config["comparative"]["iqtree"]["extra"]
    log:
        "logs/iqtree.log"
    threads:
        config["comparative"]["iqtree"]["threads"]
    conda:
        "../envs/comparative.yaml"
    shell:
        "iqtree "
        "-s {input.alignment} "
        "--prefix {params.prefix} "
        "-T {threads} "
        "{params.extra} "
        "-redo > {log} 2>&1"

rule visualize_tree:
    input:
        treefile="results/comparative/iqtree/core_genome.treefile",
        script="workflow/scripts/visualize_tree.py"
    output:
        png="results/comparative/iqtree/core_genome_tree.png"
    log:
        "logs/visualize_tree.log"
    conda:
        "../envs/plotting.yaml"
    shell:
        "python {input.script} {input.treefile} {output.png} > {log} 2>&1"
