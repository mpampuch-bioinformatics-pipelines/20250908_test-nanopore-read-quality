process YAK_INSPECT {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/yak:0.1--he4a0461_4'
        : 'biocontainers/yak:0.1--he4a0461_4'}"

    input:
    // input channels: [[id: meta.id], [yak1, yak2]] or [[id: meta.id], yak]
    tuple val(meta), path(yak_files)

    output:
    tuple val(meta), path("*.kqv.txt"), emit: kqv, optional: true
    tuple val(meta), path("*.hist"), emit: hist, optional: true
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.e

    if (yak_files instanceof List && yak_files.size() == 2) {
        // Two yak files - run comparison
        // input channel: [[id: meta.id], [yak1, yak2]]
        def yak1 = yak_files[0]
        def yak2 = yak_files[1]
        """
        yak \\
            inspect \\
            ${args} \\
            -t${task.cpus} \\
            ${yak1} \\
            ${yak2} \\
            > ${prefix}.kqv.txt 

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            yak: \$(yak version)
        END_VERSIONS
        """
    }
    else {
        // Single yak file - run individual inspection only
        // input channel: [[id: meta.id], yak]
        def yak_file = yak_files[0]
        def yak_hist = yak_files.getBaseName() + '.hist'
        """
        yak inspect ${yak_file} > ${yak_hist}

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            yak: \$(yak version)
        END_VERSIONS
        """
    }

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    if (yak_files instanceof List && yak_files.size() == 2) {
        // input channel: [[id: meta.id], [yak1, yak2]]
        """
        touch ${prefix}.kqv.txt

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            yak: \$(yak version)
        END_VERSIONS
        """
    }
    else {
        // input channel: [[id: meta.id], yak]
        def yak_file = yak_files[0]
        def yak_hist = yak_file.getBaseName() + '.hist'
        """
        touch ${yak_hist}

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            yak: \$(yak version)
        END_VERSIONS
        """
    }
}
