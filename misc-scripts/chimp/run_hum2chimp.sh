#!/bin/sh

/usr/local/ensembl/bin/perl human2chimp.pl -hdbname homo_sapiens_core_20_34b -hhost ecs4 -huser ensro -hport 3351 -cdbname mcvicker_chimp_human_merge -chost ecs4 -cport 3350 -cuser ensro -hassembly NCBI34 -cassembly BROAD1 -logfile chimp.log -store -duser ensadmin -dpass ensembl -dhost ecs1d -ddbname mcvicker_chimp_gene_transfer
