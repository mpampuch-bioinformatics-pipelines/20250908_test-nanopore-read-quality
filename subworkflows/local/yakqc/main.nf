// TODO nf-core: If in doubt look at other nf-core/subworkflows to see how we are doing things! :)
//               https://github.com/nf-core/modules/tree/master/subworkflows
//               You can also ask for help via your pull request or on the #subworkflows channel on the nf-core Slack workspace:
//               https://nf-co.re/join
// TODO nf-core: A subworkflow SHOULD import at least two modules

include { YAK_COUNT as YAK_COUNT_ILLUMINA                      } from '../../../modules/nf-core/yak/count/main'
include { YAK_COUNT as YAK_COUNT_NANOPORE                      } from '../../../modules/nf-core/yak/count/main'
include { YAK_COUNT as YAK_COUNT_PACBIO                        } from '../../../modules/nf-core/yak/count/main'
include { YAK_QV as YAK_QV_NANOPORE                            } from '../../../modules/local/yak/qv/main'
include { YAK_QV as YAK_QV_PACBIO                              } from '../../../modules/local/yak/qv/main'
include { YAK_INSPECT as YAK_INSPECT_KMER_SENSITIVITY_NANOPORE } from '../../../modules/local/yak/inspect/main'
include { YAK_INSPECT as YAK_INSPECT_KMER_SENSITIVITY_PACBIO   } from '../../../modules/local/yak/inspect/main'
include { YAK_INSPECT as YAK_INSPECT_ILLUMINA_HIST             } from '../../../modules/local/yak/inspect/main'
include { YAK_INSPECT as YAK_INSPECT_NANOPORE_HIST             } from '../../../modules/local/yak/inspect/main'
include { YAK_INSPECT as YAK_INSPECT_PACBIO_HIST               } from '../../../modules/local/yak/inspect/main'

workflow YAKQC {
    take:
    ch_samplesheet // channel: [ val(meta), [ ilmn_fastq1, ilmn_fastq2, ont_fastq, pb_fastq ] ]

    main:
    ch_versions = Channel.empty()

    // Count k-mers in Illumina reads
    ch_samplesheet
        .map { meta, ilmn_fastq1, ilmn_fastq2, _ont_fastq, _pb_fastq ->
            return [[id: meta.id, single_end: false], [ilmn_fastq1, ilmn_fastq2]]
        }
        .set { ch_yak_count_input_paired_end_ilmn_reads }

    // input channel: [ [id: meta.id], [ilmn_fastq1, ilmn_fastq2] ]
    YAK_COUNT_ILLUMINA(ch_yak_count_input_paired_end_ilmn_reads)
    ch_yak_count_illumina = YAK_COUNT_ILLUMINA.out.yak
    ch_versions = ch_versions.mix(YAK_COUNT_ILLUMINA.out.versions.first())

    // Count k-mers in Nanopore reads
    ch_samplesheet
        .map { meta, _ilmn_fastq1, _ilmn_fastq2, ont_fastq, _pb_fastq ->
            return [[id: meta.id, single_end: true], ont_fastq]
        }
        .set { ch_yak_count_input_single_end_nanopore_reads }

    YAK_COUNT_NANOPORE(ch_yak_count_input_single_end_nanopore_reads)
    ch_yak_count_nanopore = YAK_COUNT_NANOPORE.out.yak
    ch_versions = ch_versions.mix(YAK_COUNT_NANOPORE.out.versions.first())

    // Count k-mers in PacBio reads
    ch_samplesheet
        .map { meta, _ilmn_fastq1, _ilmn_fastq2, _ont_fastq, pb_fastq ->
            return [[id: meta.id, single_end: true], pb_fastq]
        }
        .set { ch_yak_count_input_single_end_pacbio_reads }

    YAK_COUNT_PACBIO(ch_yak_count_input_single_end_pacbio_reads)
    ch_yak_count_pacbio = YAK_COUNT_PACBIO.out.yak
    ch_versions = ch_versions.mix(YAK_COUNT_PACBIO.out.versions.first())

    // Get QV for Nanopore reads
    ch_nanopore_fastq = ch_samplesheet.map { meta, _ilmn_fastq1, _ilmn_fastq2, ont_fastq, _pb_fastq ->
        return [meta, ont_fastq]
    }
    ch_yak_qv_nanopore_input = ch_yak_count_illumina.map { meta, yak -> [[id: meta.id], yak] }.combine(ch_nanopore_fastq, by: 0)

    // input(channel: [[id: meta.id], yak, ont_fastq])
    YAK_QV_NANOPORE(ch_yak_qv_nanopore_input)
    ch_yak_qv_nanopore = YAK_QV_NANOPORE.out.qv
    ch_versions = ch_versions.mix(YAK_QV_NANOPORE.out.versions.first())

    // Get QV for PacBio reads
    ch_pacbio_fastq = ch_samplesheet.map { meta, _ilmn_fastq1, _ilmn_fastq2, _ont_fastq, pb_fastq ->
        return [meta, pb_fastq]
    }
    ch_yak_qv_pacbio_input = ch_yak_count_illumina.map { meta, yak -> [[id: meta.id], yak] }.combine(ch_pacbio_fastq, by: 0)

    YAK_QV_PACBIO(ch_yak_qv_pacbio_input)
    ch_yak_qv_pacbio = YAK_QV_PACBIO.out.qv
    ch_versions = ch_versions.mix(YAK_QV_PACBIO.out.versions.first())


    // Compute k-mer QV for Nanopore reads
    ch_yak_inspect_input_nanopore = ch_yak_count_nanopore
        .map { meta, yak -> [[id: meta.id], yak] }
        .join(ch_yak_count_illumina.map { meta, yak -> [[id: meta.id], yak] })
        .map { meta, yak_nanopore, yak_illumina ->
            return [[id: meta.id], yak_nanopore, yak_illumina]
        }

    // Compute k-mer QV for PacBio reads
    ch_yak_inspect_input_pacbio = ch_yak_count_pacbio
        .map { meta, yak -> [[id: meta.id], yak] }
        .join(ch_yak_count_illumina.map { meta, yak -> [[id: meta.id], yak] })
        .map { meta, yak_pacbio, yak_illumina ->
            return [[id: meta.id], yak_pacbio, yak_illumina]
        }

    // Evaluates the k-mer QV of in1.yak and the k-mer sensitivity of in2.yak, Nanopore Reads 
    // input(channel: [[id: meta.id], [yak_nanopore, yak_illumina]])
    YAK_INSPECT_KMER_SENSITIVITY_NANOPORE(
        ch_yak_inspect_input_nanopore.map { meta, yak_nanopore, yak_illumina ->
            return [[id: meta.id], [yak_nanopore, yak_illumina]]
        }
    )
    ch_yak_inspect_kqv_nanopore = YAK_INSPECT_KMER_SENSITIVITY_NANOPORE.out.kqv
    ch_versions = ch_versions.mix(YAK_INSPECT_KMER_SENSITIVITY_NANOPORE.out.versions.first())

    // Evaluates the k-mer QV of in1.yak and the k-mer sensitivity of in2.yak, PacBio Reads
    YAK_INSPECT_KMER_SENSITIVITY_PACBIO(
        ch_yak_inspect_input_pacbio.map { meta, yak_pacbio, yak_illumina ->
            return [[id: meta.id], [yak_pacbio, yak_illumina]]
        }
    )
    ch_yak_inspect_kqv_pacbio = YAK_INSPECT_KMER_SENSITIVITY_PACBIO.out.kqv
    ch_versions = ch_versions.mix(YAK_INSPECT_KMER_SENSITIVITY_PACBIO.out.versions.first())

    // input channel: [ [id: meta.id], yak_nanopore ]
    YAK_INSPECT_NANOPORE_HIST(
        ch_yak_inspect_input_nanopore.map { meta, yak_nanopore, _yak_illumina ->
            return [[id: meta.id], yak_nanopore]
        }
    )
    ch_yak_inspect_nanopore_hist = YAK_INSPECT_NANOPORE_HIST.out.hist
    ch_versions = ch_versions.mix(YAK_INSPECT_NANOPORE_HIST.out.versions.first())

    // Inspect PacBio reads
    YAK_INSPECT_PACBIO_HIST(
        ch_yak_inspect_input_pacbio.map { meta, yak_pacbio, _yak_illumina ->
            return [[id: meta.id], yak_pacbio]
        }
    )
    ch_yak_inspect_pacbio_hist = YAK_INSPECT_PACBIO_HIST.out.hist
    ch_versions = ch_versions.mix(YAK_INSPECT_PACBIO_HIST.out.versions.first())

    // input channel: [ [id: meta.id], yak_illumina ]
    YAK_INSPECT_ILLUMINA_HIST(
        ch_yak_count_illumina.map { meta, yak ->
            return [[id: meta.id], yak]
        }
    )
    ch_yak_inspect_illumina_hist = YAK_INSPECT_ILLUMINA_HIST.out.hist
    ch_versions = ch_versions.mix(YAK_INSPECT_ILLUMINA_HIST.out.versions.first())

    emit:
    reads_qv_nanopore = ch_yak_qv_nanopore
    reads_qv_pacbio   = ch_yak_qv_pacbio
    kmer_qv_nanopore  = ch_yak_inspect_kqv_nanopore
    kmer_qv_pacbio    = ch_yak_inspect_kqv_pacbio
    nanopore_hist     = ch_yak_inspect_nanopore_hist
    pacbio_hist       = ch_yak_inspect_pacbio_hist
    illumina_hist     = ch_yak_inspect_illumina_hist
    versions          = ch_versions // channel: [ versions.yml ]
}
