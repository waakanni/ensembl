#
# Ensembl module for Bio::EnsEMBL::DBSQL::ProteinAlignFeatureAdaptor
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::DBSQL::ProteinAlignFeatureAdaptor - 
Adaptor for ProteinAlignFeatures

=head1 SYNOPSIS

    $pafa = $dbadaptor->get_ProteinAlignFeatureAdaptor();

    my @features = @{$pafa->fetch_all_by_Slice($slice)};

    $pafa->store(@features);


=head1 DESCRIPTION


=head1 CONTACT

Post questions to the Ensembl development list: ensembl-dev@ebia.ac.uk

=head1 METHODS

=cut


package Bio::EnsEMBL::DBSQL::ProteinAlignFeatureAdaptor;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::BaseAlignFeatureAdaptor;
use Bio::EnsEMBL::DnaPepAlignFeature;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAlignFeatureAdaptor);


=head2 store

  Arg [1]    : list of Bio::EnsEMBL::DnaPepAlignFeature @feats
  Example    : $protein_align_feature_adaptor->store(@feats);
  Description: stores a list of ProteinAlignFeatures in the database
  Returntype : none
  Exceptions : throw if any of the provided features cannot be stored
               which may occur if:
                 * The feature does not have an associated Slice
                 * The feature does not have an associated analysis
                 * The Slice the feature is associated with is on a seq_region
                   unknown to this database
              A warning is given if:
                 * The feature has already been stored in this db
  Caller     : Pipeline

=cut


sub store{
 my ($self, @feats) = @_;

  throw("Must call store with features") if( scalar(@feats) == 0 );

  my @tabs = $self->_tables;
  my ($tablename) = @{$tabs[0]};

  my $db = $self->db();
  my $slice_adaptor = $db->get_SliceAdaptor();
  my $analysis_adaptor = $db->get_AnalysisAdaptor();

  my $sth = $self->prepare(
     "INSERT INTO $tablename (seq_region_id, seq_region_start, seq_region_end,
                             seq_region_strand, hit_start, hit_end,
                             hit_name, cigar_line,
                             analysis_id, score, evalue, perc_ident)
     VALUES (?,?,?,?,?,?,?,?,?,?, ?, ?)");

 FEATURE: foreach my $feat ( @feats ) {
   if( !ref $feat || !$feat->isa("Bio::EnsEMBL::DnaPepAlignFeature") ) {
     throw("feature must be a Bio::EnsEMBL::DnaPepAlignFeature,"
           . " not a [".ref($feat)."].");
   }

   if($feat->is_stored($db)) {
     warning("PepDnaAlignFeature [".$feat->dbID."] is already stored" .
             " in this database.");
     next FEATURE;
   }

   #sanity check the hstart and hend
   my $hstart  = $feat->hstart();
   my $hend    = $feat->hend();
   $self->_check_start_end_strand($hstart,$hend,1);

   my $cigar_string = $feat->cigar_string();
   if(!$cigar_string) {
     $cigar_string = $feat->length() . 'M';
     warning("DnaPepAlignFeature does not define a cigar_string.\n" .
             "Assuming ungapped block with cigar_string=$cigar_string\n");
   }

   my $hseqname = $feat->hseqname();
   if(!$hseqname) {
     throw("DnaPepAlignFeature must define an hseqname.");
   }

   if(!defined($feat->analysis)) {
     throw("An analysis must be attached to the features to be stored.");
   }

   #store the analysis if it has not been stored yet
   if(!$feat->analysis->is_stored($db)) {
     $analysis_adaptor->store($feat->analysis());
   }

   my $slice = $feat->slice();
   if(!defined($slice) || !$slice->isa("Bio::EnsEMBL::Slice")) {
     throw("A slice must be attached to the features to be stored.");
   }

   my $original = $feat;
   my $seq_region_id;
   ($feat, $seq_region_id) = $self->_pre_store($feat);

   $sth->execute( $seq_region_id, $feat->start, $feat->end, $feat->strand,
                  $feat->hstart, $feat->hend, $feat->hseqname,
                  $feat->cigar_string, $feat->analysis->dbID, $feat->score,
                  $feat->p_value, $feat->percent_id);
   $original->dbID($sth->{'mysql_insertid'});
   $original->adaptor($self);
 }

 $sth->finish();
}


=head2 _objs_from_sth

  Arg [1]    : DBI statement handle $sth
               an exectuted DBI statement handle generated by selecting 
               the columns specified by _columns() from the table specified 
               by _table()
  Example    : @dna_dna_align_feats = $self->_obj_from_hashref
  Description: PROTECTED implementation of superclass abstract method. 
               Creates DnaDnaAlignFeature objects from a DBI hashref
  Returntype : listref of Bio::EnsEMBL::ProteinAlignFeatures
  Exceptions : none
  Caller     : Bio::EnsEMBL::BaseFeatureAdaptor::generic_fetch

=cut

sub _objs_from_sth {
  my ($self, $sth, $mapper, $dest_slice) = @_;

  #
  # This code is ugly because an attempt has been made to remove as many
  # function calls as possible for speed purposes.  Thus many caches and
  # a fair bit of gymnastics is used.
  #

  my $sa = $self->db()->get_SliceAdaptor();
  my $aa = $self->db->get_AnalysisAdaptor();

  my @features;
  my %analysis_hash;
  my %slice_hash;
  my %sr_name_hash;
  my %sr_cs_hash;

  my ($protein_align_feature_id, $seq_region_id, $seq_region_start,
      $seq_region_end, $analysis_id, $seq_region_strand, $hit_start,
      $hit_end, $hit_name, $cigar_line, $evalue, $perc_ident, $score);

  $sth->bind_columns(\$protein_align_feature_id, \$seq_region_id,
           \$seq_region_start,\$seq_region_end, \$analysis_id,
           \$seq_region_strand, \$hit_start,\$hit_end, \$hit_name,
           \$cigar_line, \$evalue, \$perc_ident, \$score);

  my $asm_cs;
  my $cmp_cs;
  my $asm_cs_vers;
  my $asm_cs_name;
  my $cmp_cs_vers;
  my $cmp_cs_name;
  if($mapper) {
    $asm_cs = $mapper->assembled_CoordSystem();
    $cmp_cs = $mapper->component_CoordSystem();
    $asm_cs_name = $asm_cs->name();
    $asm_cs_vers = $asm_cs->version();
    $cmp_cs_name = $cmp_cs->name();
    $cmp_cs_vers = $cmp_cs->version();
  }

  my $dest_slice_start;
  my $dest_slice_end;
  my $dest_slice_strand;
  my $dest_slice_length;
  if($dest_slice) {
    $dest_slice_start  = $dest_slice->start();
    $dest_slice_end    = $dest_slice->end();
    $dest_slice_strand = $dest_slice->strand();
    $dest_slice_length = $dest_slice->length();
  }

  FEATURE: while($sth->fetch()) {
    #get the analysis object
    my $analysis = $analysis_hash{$analysis_id} ||=
      $aa->fetch_by_dbID($analysis_id);

    #get the slice object
    my $slice = $slice_hash{"ID:".$seq_region_id};

    if(!$slice) {
      $slice = $sa->fetch_by_seq_region_id($seq_region_id);
      $slice_hash{"ID:".$seq_region_id} = $slice;
      $sr_name_hash{$seq_region_id} = $slice->seq_region_name();
      $sr_cs_hash{$seq_region_id} = $slice->coord_system();
    }

    #
    # remap the feature coordinates to another coord system
    # if a mapper was provided
    #
    if($mapper) {
      my $sr_name = $sr_name_hash{$seq_region_id};
      my $sr_cs   = $sr_cs_hash{$seq_region_id};

      ($sr_name,$seq_region_start,$seq_region_end,$seq_region_strand) =
        $mapper->fastmap($sr_name, $seq_region_start, $seq_region_end,
                          $seq_region_strand, $sr_cs);

      #skip features that map to gaps or coord system boundaries
      next FEATURE if(!defined($sr_name));

      #get a slice in the coord system we just mapped to
      if($asm_cs == $sr_cs || ($cmp_cs != $sr_cs && $asm_cs->equals($sr_cs))) {
        $slice = $slice_hash{"NAME:$sr_name:$cmp_cs_name:$cmp_cs_vers"} ||=
          $sa->fetch_by_region($cmp_cs_name, $sr_name,undef, undef, undef,
                               $cmp_cs_vers);
      } else {
        $slice = $slice_hash{"NAME:$sr_name:$asm_cs_name:$asm_cs_vers"} ||=
          $sa->fetch_by_region($asm_cs_name, $sr_name, undef, undef, undef,
                               $asm_cs_vers);
      }
    }

    #
    # If a destination slice was provided convert the coords
    # If the dest_slice starts at 1 and is foward strand, nothing needs doing
    #
    if($dest_slice) {
      if($dest_slice_start != 1 || $dest_slice_strand != 1) {
        if($dest_slice_strand == 1) {
          $seq_region_start = $seq_region_start - $dest_slice_start + 1;
          $seq_region_end   = $seq_region_end   - $dest_slice_start + 1;
        } else {
          my $tmp_seq_region_start = $seq_region_start;
          $seq_region_start = $dest_slice_end - $seq_region_end + 1;
          $seq_region_end   = $dest_slice_end - $tmp_seq_region_start + 1;
          $seq_region_strand *= -1;
        }
	
        #throw away features off the end of the requested slice
        if($seq_region_end < 1 || $seq_region_start > $dest_slice_length) {
          next FEATURE;
        }
      }
      $slice = $dest_slice;
    }

    #finally, create the new dna align feature
    push @features, Bio::EnsEMBL::DnaPepAlignFeature->new_fast
      ( { 'slice'         =>  $slice,
          'start'         =>  $seq_region_start,
          'end'           =>  $seq_region_end,
          'strand'        =>  $seq_region_strand,
          'hseqname'      =>  $hit_name,
          'hstart'        =>  $hit_start,
          'hend'          =>  $hit_end,
          'hstrand'       =>  1, #dna_pep_align features are always hstrand 1
          'score'         =>  $score,
          'p_value'       =>  $evalue,
          'percent_id'    =>  $perc_ident,
          'cigar_string'  =>  $cigar_line,
          'analysis'      =>  $analysis,
          'adaptor'       =>  $self,
          'dbID'          =>  $protein_align_feature_id } );
  }

  return \@features;
}



sub _tables {
  my $self = shift;

  return ['protein_align_feature', 'paf'];
}


sub _columns {
  my $self = shift;

  #warning _objs_from_hashref method depends on ordering of this list 
  return qw( paf.protein_align_feature_id
             paf.seq_region_id
             paf.seq_region_start
             paf.seq_region_end
             paf.analysis_id
             paf.seq_region_strand
             paf.hit_start
             paf.hit_end
             paf.hit_name
             paf.cigar_line
             paf.evalue
             paf.perc_ident
             paf.score );
}

=head2 list_dbIDs

  Arg [1]    : none
  Example    : @feature_ids = @{$protein_align_feature_adaptor->list_dbIDs()};
  Description: Gets an array of internal ids for all protein align 
               features in the current db
  Returntype : listref of ints
  Exceptions : none
  Caller     : ?

=cut

sub list_dbIDs {
   my ($self) = @_;

   return $self->_list_dbIDs("protein_align_feature");
}






1;
