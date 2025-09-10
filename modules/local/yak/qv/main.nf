process YAK_QV {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/yak:0.1--he4a0461_4'
        : 'biocontainers/yak:0.1--he4a0461_4'}"

    input:
    tuple val(meta), path(child_yak), path(reads)

    output:
    tuple val(meta), path("*.qv.txt"), emit: qv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    yak \\
        qv \\
        ${args} \\
        -t${task.cpus} \\
        ${child_yak} \\
        ${reads} \\
        > ${prefix}.qv.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        yak: \$(yak version)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.qv.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        yak: \$(yak version)
    END_VERSIONS
    """
}
