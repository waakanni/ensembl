
#
# BioPerl module for MapContig
#
# Cared for by Elia Stupka <elia@ebi.ac.uk>
#
# Copyright Elia Stupka
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

MapContig - Object holding the map of contigs within a VirtualContig

=head1 SYNOPSIS

This object should only be used internally by VirtualContig

=head1 DESCRIPTION

This object holds the information regarding the contigs found within 
a VirtualContig

=head1 CONTACT

e-mail: elia@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


# Let the code begin...

package Bio::EnsEMBL::DB::MapContig;
use vars qw(@ISA);
use strict;
# Object preamble - inheriets from Bio::Root::Object

use Bio::Root::Object;


@ISA = qw(Bio::Root::Object);
# new() is inherited from Bio::Root::Object

# _initialize is where the heavy stuff will happen when new is called

sub _initialize {
  my($self,@args) = @_;

  my ($contig,$ori,$start,$startin) = $self->_rearrange([qw( CONTIG ORI START STARTIN)],@args);

  $contig || $self->("Cannot create a MapContig without a contig object!");
  
  $self->contig($contig);
  $self->orientation($ori);
  $self->start($start);
  $self->start_in($startin);

  my $make = $self->SUPER::_initialize;

# set stuff in self from @args
 return $make; # success - we hope!
}

=head2 contig

 Title   : contig
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub contig{
    my ($obj,$value) = @_;
    
    if( defined $value) {
	$obj->{'_contig'} = $value;
    }
    return $obj->{'_contig'};
}

=head2 orientation

 Title   : orientation
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub orientation{
    my ($obj,$value) = @_;
    
    if( defined $value) {
	$obj->{'_ori'} = $value;
    }
    return $obj->{'_ori'};
}


=head2 start

 Title   : start
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub start{
    my ($obj,$value) = @_;
    
    if( defined $value) {
	$obj->{'_start'} = $value;
    }
    return $obj->{'_start'};
}

=head2 end

 Title   : end
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub end{
    my ($self) = @_;
    my $end = $self->rightmost_end;
    if(defined $end) {
	if( $self->orientation == 1 ) {
	    return $self->start + ($end - $self->start_in);
	} else {
	    #print STDERR "Returning on end... ",$self->start," ",$self->start_in," ",$end,"\n";
	    return $self->start + ($self->start_in - $end);
	}
    } elsif ( $self->leftmost ) {
	#print STDERR "Using leftmost for ",$self->contig->id,"\n";

	# not the entire golden length used here (!)
	# the mysterious +1 is to keep the overlapping base convention.
	if( $self->orientation == 1 ) {
	    return $self->start + ($self->contig->golden_end - $self->start_in -1);
	} else {
	    return $self->start + ($self->start_in - $self->contig->golden_start -1);
	}
    } else {
	return $self->start + $self->contig->golden_length-1;
    } 
}

sub length {
    my $self = shift;

    return $self->end - $self->start +1;
}


sub _leftmost_end {
    my ($obj,$value) = @_;
    
    if( defined $value) {
	$obj->{'_leftmost_end'} = $value;
    }
    return $obj->{'_leftmost_end'};
}

    
=head2 end_in

 Title   : end_in
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub end_in {
    my ($self) = @_;

    $self->throw("No start_in defined") unless defined($self->start_in);
    if( $self->orientation == 1 ) {
	return $self->start_in + ($self->end - $self->start);
    } else {
	return $self->start_in - ($self->end - $self->start);
    }

}


=head2 rightmost_end

 Title   : rightmost_end
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub rightmost_end{
    my ($obj,$value) = @_;
    
    if( defined $value) {
	if( $value <= 0 || $value > $obj->contig->length ) {
	    $obj->throw("Not possible to have a rightmost_end at $value with contig length".$obj->contig->length);
	}
	$obj->{'_rightmost_end'} = $value;
    }
    return $obj->{'_rightmost_end'};
}


=head2 leftmost

 Title   : leftmost
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub leftmost{
    my ($obj,$value) = @_;
    
    if( defined $value) {
	$obj->{'_leftmost'} = $value;
    }
    return $obj->{'_leftmost'};
}

=head2 start_in

 Title   : start_in
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub start_in{
    my ($obj,$value) = @_;
    
    if( defined $value) {
	$obj->{'_startin'} = $value;
    }
    return $obj->{'_startin'};
}

