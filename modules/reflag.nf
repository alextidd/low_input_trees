process reflag_run {
  tag "${meta.sample_id}:${vcf_type}"
  label "normal4core"
  publishDir "${params.outdir}/${meta.donor_id}/${vcf_type}/${meta.sample_id}", 
    mode: "copy",
    pattern: "*_reflagged.vcf"

  input:
  tuple val(meta), 
        val(vcf_type), path(vcf), 
        path(bam), path(bai), path(bas), path(met)

  output:
  tuple val(meta), 
        val(vcf_type), path("${meta.sample_id}_reflagged.vcf"), 
        path(bam), path(bai), path(bas), path(met)

  script:
  if (vcf_type == "pindel") {
    if (params.project_type == "TGS" || params.project_type == "WES") {
      // remove FF009 (required exonic)
      flags = "FF009"
    } else if (params.project_type == "WGS") {
      // turn off FF016 flag (min 5 reads)  
      // turn off FF018 flag (min depth 10 in query and normal)
      flags = "FF016,FF018"
    } 
  } else if (vcf_type == "caveman") {
    // turn off MNP flag (requires VAF > 0.2 if any muntant reads in normal)
    flags = "MNP"
  }
  """
  # check that the flags exist in the input file
  IFS=',' read -r -a array <<< "${flags}"
  present_flags=()
  for flag in "\${array[@]}" ; do
    if grep -q "\$flag" <(zcat ${vcf}) ; then
      echo "Flag \${flag} not found in ${vcf}. Ignoring!"
    else 
      present_flags+=("--flagremove \${flag}")
    fi
  done

  # if flags exist reflag, else rename
  if [ \${#present_flags[@]} -gt 0 ]; then
    vcf_flag_modifier.py \
      -f ${vcf} \
      -o ${meta.sample_id}_reflagged.vcf \
      \${present_flags[@]}
  else 
    cp ${vcf} ${meta.sample_id}_reflagged.vcf
  fi
  """
}

workflow reflag {
  take: 
  ch_caveman
  ch_pindel

  main:
  // reflag and split channels
  ch_caveman.concat(ch_pindel)
  | reflag_run
  | branch {
      meta, vcf_type, vcf, bam, bai, bas, met ->
      caveman: vcf_type == "caveman"
        return tuple(meta, vcf_type, vcf, bam, bai, bas, met)
      pindel: vcf_type == "pindel"
        return tuple(meta, vcf_type, vcf, bam, bai, bas, met)
  } | set { ch_reflagged }

  emit:
  ch_caveman_reflagged = ch_reflagged.caveman
  ch_pindel_reflagged = ch_reflagged.pindel
}

