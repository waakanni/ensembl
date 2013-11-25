=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package XrefMapper::Methods::MySQLUniParc;

use strict;
use warnings;

use base qw/XrefMapper::Methods::ChecksumBasic/;

use Bio::EnsEMBL::Utils::Exception qw(throw);

my $UNIPARC_SQL = <<SQL;
select accession
from checksum_xref
where checksum =?
SQL

sub perform_mapping {
  my ($self, $sequences) = @_;
  
  my @final_results;
  
  $self->mapper()->xref()->dbc()->sql_helper()->batch(-SQL => $UNIPARC_SQL, -CALLBACK => sub {
    my ($sth) = @_;
    foreach my $sequence (@{$sequences}) {
      my $checksum = uc($self->md5_checksum($sequence));
      $sth->execute($checksum);
      my $upi;
      while(my $row = $sth->fetchrow_arrayref()) {
        my ($local_upi) = @{$row};
        if(defined $upi) {
          throw sprintf('The sequence %s had a checksum of %s but this resulted in more than one UPI: [%s, %s]', $sequence->id(), $checksum, $upi, $local_upi);
        }
        $upi = $local_upi;
      }
      if(defined $upi){
        push(@final_results, { id => $sequence->id(), upi => $upi, object_type => 'Translation' });
      }
    }
    return;
  });
  
  return \@final_results;
}