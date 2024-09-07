include { samplesheetToList } from 'plugin/nf-schema'

workflow preprocess {
  main:
  
  // TODO: change these reference files from channels to files
  // get fasta + fai
  faste = \
    [file(params.fasta, checkIfExists: true),
     file(params.fasta + ".fai", checkIfExists: true)]

  // get bed + tbi
  high_depth_bed = \
    [file(params.high_depth_bed, checkIfExists: true),
     file(params.high_depth_bed + ".tbi", checkIfExists: true)]

  // get cgpVAF normal bam + bai
  cgpVAF_normal_bam = \
    [file(params.cgpVAF_normal_bam),
     file(params.cgpVAF_normal_bam + ".bas", checkIfExists: true),
     file(params.cgpVAF_normal_bam + ".bai", checkIfExists: true),
     file(params.cgpVAF_normal_bam + ".met.gz", checkIfExists: true)]

  // get metadata + bam paths
  // TODO: check if we actually need bas and met files
  Channel.fromList(samplesheetToList(params.sample_sheet, "./assets/schema_sample_sheet.json"))
  | map { meta, bam, caveman_vcf, pindel_vcf ->
          [meta, 
          file(caveman_vcf),
          file(pindel_vcf),
          file(bam),
          // get bam's index, bas and met files
          file(bam + ".bai", checkIfExists: true),
          file(bam + ".bas", checkIfExists: true),
          file(bam + ".met.gz", checkIfExists: true)]}
  | set { ch_samples }

  // get caveman vcfs
  ch_samples 
  | map { meta, caveman_vcf, pindel_vcf, bam, bai, bas, met ->
          [meta + [vcf_type: "caveman"], caveman_vcf, bam, bai, bas, met]
  }
  | set { ch_caveman }

  // get pindel vcfs
  ch_samples 
  | map { meta, caveman_vcf, pindel_vcf, bam, bai, bas, met ->
          [meta + [vcf_type: "pindel"], pindel_vcf, bam, bai, bas, met]
  }
  | set { ch_pindel }

  // concat channels
  ch_caveman.concat(ch_pindel)
  | set { ch_input }

  emit:
  ch_input = ch_input
  fasta = fasta
  high_depth_bed = high_depth_bed
  cgpVAF_normal_bam = cgpVAF_normal_bam
}