process reflag_run {
  tag "${meta.sample_id}:${meta.vcf_type}"
  label "normal4core"

  input:
  tuple val(meta), 
        path(vcf),
        path(bam), path(bai), path(bas), path(met)

  output:
  tuple val(meta), 
        path("${meta.sample_id}_reflagged.vcf"),
        path(bam), path(bai), path(bas), path(met)

  script:
  if (meta.vcf_type == "pindel") {
    if (params.sequencing_type == "WES") {
      // remove FF009 (required exonic)
      flags = "FF009"
    } else if (params.sequencing_type == "WGS") {
      // turn off FF016 flag (min 5 reads)  
      // turn off FF018 flag (min depth 10 in query and normal)
      flags = "FF016,FF018"
    } 
  } else if (meta.vcf_type == "caveman") {
    // turn off MNP flag (requires VAF > 0.2 if any mutant reads in normal)
    flags = "MNP"
  }
  """
  # check that the flags exist in the input file
  IFS=',' read -r -a array <<< "${flags}"
  present_flags=()
  for flag in "\${array[@]}" ; do
    if grep -q "\$flag" <(zcat ${vcf}) ; then
      present_flags+=("--flagremove \${flag}")
    else 
      echo "Flag \${flag} not found in ${vcf}. Ignoring!"
    fi
  done

  # if flags exist, reflag
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
  ch_input

  main:
  // reflag and split channels
  ch_input
  | reflag_run

  emit:
  reflag_run.out
}


