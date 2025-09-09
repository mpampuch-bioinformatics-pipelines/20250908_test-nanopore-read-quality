// TODO nf-core: If in doubt look at other nf-core/subworkflows to see how we are doing things! :)
//               https://github.com/nf-core/modules/tree/master/subworkflows
//               You can also ask for help via your pull request or on the #subworkflows channel on the nf-core Slack workspace:
//               https://nf-co.re/join
// TODO nf-core: A subworkflow SHOULD import at least two modules

include { YAK_COUNT } from '../../../modules/nf-core/yak/count/main'


workflow YAKQC {
    take:
    ch_samplesheet // channel: [ val(meta), [ ilmn_fastq1, ilmn_fastq2, ont_fastq, pb_fastq ] ]

    main:
    ch_versions = Channel.empty()



    ch_samplesheet
        .map { meta, ilmn_fastq1, ilmn_fastq2, _ont_fastq, _pb_fastq ->
            return [[id: meta.id, single_end: false], [ilmn_fastq1, ilmn_fastq2]]
        }
        .view()
        .set { ch_yak_count_input_paired_end_ilmn_reads }

    YAK_COUNT(ch_yak_count_input_paired_end_ilmn_reads)
    ch_yak_count = YAK_COUNT.out.yak
    ch_versions = ch_versions.mix(YAK_COUNT.out.versions.first())

    emit:
    versions = ch_versions // channel: [ versions.yml ]
}
