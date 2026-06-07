# Bacterial WGS Snakemake Workflow

Automated Snakemake workflow for bacterial whole-genome sequencing analysis from paired-end Illumina reads, with optional long-read support for hybrid assembly.

The workflow performs read QC, genome assembly, polishing, assembly QC, annotation, optional MLST/AMR/virulence/plasmid screening, and core-genome phylogeny reconstruction.

## Workflow Overview

```mermaid
flowchart TD
    A["Sample sheet<br/>config/samples.tsv"] --> B["Raw reads"]

    B --> C["Short-read QC<br/>fastp"]
    B --> D{"Long reads?"}

    D -- Yes --> E["Long-read QC<br/>NanoFilt + NanoPlot"]
    D -- No --> F["Short-read only"]

    C --> G{"Assembly"}
    E --> G
    F --> G

    G -- Illumina only --> H["SPAdes assembly"]
    G -- Hybrid --> I["Unicycler assembly"]

    H --> J["Read mapping<br/>bwa-mem2 + samtools"]
    I --> J
    J --> K["Polishing<br/>Pilon"]

    K --> L["Assembly QC<br/>QUAST + BUSCO"]
    C --> M["MultiQC report"]
    E --> M
    L --> M

    K --> N["Annotation<br/>Bakta"]
    N --> O["Annotated GFF3 files"]

    K --> P["Optional screening<br/>MLST / AMR / virulence / plasmids"]
    P --> Q["Screening summary<br/>Excel"]

    O --> R["Core genome alignment<br/>Panaroo"]
    R --> S["Phylogeny<br/>IQ-TREE"]
    S --> T["Tree figure<br/>PNG"]
```

## Example Output

Representative circular genome visualization generated from one sample.

![Circular bacterial genome visualization](example_circular_genome.png)

## Main Steps

1. Quality-control paired-end Illumina reads with `fastp`.
2. Optionally filter and summarize long reads with `NanoFilt` and `NanoPlot`.
3. Assemble genomes with `SPAdes` for short-read-only samples or `Unicycler` for hybrid samples.
4. Polish assemblies with `Pilon` after read mapping with `bwa-mem2` and `samtools`.
5. Assess assembly quality with `QUAST` and completeness with `BUSCO`.
6. Annotate polished assemblies with `Bakta`.
7. Optionally screen for MLST, AMR genes, virulence genes, and plasmids.
8. Build a core-genome alignment with `Panaroo` and infer a phylogeny with `IQ-TREE`.

## Inputs

The main config file is:

```text
config/config.yaml
```

The sample sheet is configured with:

```yaml
sample_sheet: "config/samples.tsv"
```

Example `config/samples.tsv`:

```text
sample    illumina_r1                         illumina_r2                         long_reads
sample1   data/SET1/sample1_R1.fastq.gz       data/SET1/sample1_R2.fastq.gz       data/SET1/sample1_long.fastq.gz
sample2   data/SET2/sample2_R1.fastq.gz       data/SET2/sample2_R2.fastq.gz       -
```
