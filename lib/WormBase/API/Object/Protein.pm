package WormBase::API::Object::Protein;

use Moose;
use Bio::Tools::SeqStats;
use pICalculator;
use Bio::Graphics::Feature;
use Bio::Graphics::Panel;
use Digest::MD5 'md5_hex';

with 'WormBase::API::Role::Object';
extends 'WormBase::API::Object';
 

use vars qw(%HIT_CACHE @tags);
%HIT_CACHE=();


has 'peptide' => (
    is  => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub {
	my $self = shift;
	my $peptide = $self ~~ 'asPeptide';
	$peptide =~ s/^>.*//;
	$peptide =~ s/\n//g;   
	return $peptide;
    }
);

has 'cds' => (
    is  => 'ro',
#     isa => 'Ace::Object',
    lazy => 1,
    default => sub {
	my $self = shift;
	return $self ~~ '@Corresponding_CDS';
    }
);

 
############################################################
#
# The Overview widget
#
############################################################



sub name {
    my $self = shift;
    my $id = $self->object;
    my $ace = eval { $self->cds->[0]->Gene->CGC_name } || $id;
    
    my $data = { description => 'The name of the protein',
		 data        => { id    => "$id",
				   label => $ace->name,
				   class => $id->class
		 },

    };
    return $data;
}


sub taxonomy {
    my $self = shift;
    my $genus_species = $self ~~ 'Species' || eval { $self->cds->[0]->Species };
    my ($genus,$species) = $genus_species =~ /(.*) (.*)/;
    my $data = { description => 'the genus and species of the protein object',
		 data        => { genus   => $genus,
				  species => $species,
		 }
    };
    return $data;
}

 
sub genes {
    my $self = shift;
    my %seen;
    my @result;
    my @genes = grep {!$seen{$_}++}   grep{$_->Method ne 'history'}  @{$self->cds};
    foreach (@genes) {
   		push @result, { id=>$_->Gene,
						label=>$self->bestname($_->Gene)||$_,
						class=>'gene',
						}; 
    }
    my $data = { description => 'The genes or CDS associated with the protein',
		 data        => \@result,
    }; 
    return $data;
}


sub transcripts {
    my $self = shift;
    my %seen;
    my @transcripts = grep{$_->Method ne 'history'} @{$self->cds};
    push @transcripts, map {$_->Corresponding_transcript}  @transcripts;
    my $data = { description => 'The transcripts related with the protein',
		 data        => [map {my $hash = { id => $_,label=>$_,class=>$_->class} ;$_=$hash;} grep {!$seen{$_}++}  @transcripts],
    }; 
    return $data;

}


sub type {
    my $self = shift;
    my $data = { description => 'The type of the protein',
		 data        =>  eval {$self->cds->[0]->Method} || 'None' ,
    }; 
    return $data;
}

sub remarks {   
    my $data = { description => 'The remark of the protein',
		 data        =>  shift ~~ 'Remark'  ,
    }; 
    return $data;
}

sub status {
    
    my $data = { description => 'The status of the protein',
		 data        =>  shift ~~ 'Status' ,
    }; 
    return $data;
}

sub description {
     
    my $data = { description => 'The description of the protein',
		 data        =>  shift ~~ 'Description'  ,
    }; 
    return $data;
}

############################################################
#
# The External link widget
#
############################################################ 

sub external_links {
    my $id = eval{shift->cds->[0]}  ;
    my $data = { description => 'The orthology genes of the protein',
		 data        =>  { 'Information in Phosphopep' =>
				      { id => $id  ,
					label=>$id,
					class=>'phosphopep',
				      }
				  }
    }; 
    return $data;
 
}

 
############################################################
#
# The Homology widget
#
############################################################
sub homology_groups {
    my $self = shift;
    my $kogs= $self ~~ '@Homology_group';
    my @hg;
    foreach my $k (@$kogs) {
	push @hg ,{ type=>$k->Group_type||'',
		     title=>$k->Title||'',
		     link => { id=>"$k",
                             label=>$k->name,
                             class=>$k->class,
				}
		   };
    }
    @hg = ('not assigned') unless(@hg);
    my $data = { description => 'The homology groups of the protein',
		 data        => \@hg,
    }; 
    return $data;
}

sub ortholog_genes {
    my $self = shift;
    my $data = { description => 'The orthology genes of the protein',
		 data        =>  $self ~~ 'Ortholog_gene'  ,
    }; 
    return $data;
}

sub homology_image {
    my $self=shift;
    my $panel=$self->_draw_image($self->object,1);
    my $gd=$panel->gd;
 
    my ($suffix,$img,$boxes);
    if ($gd->isa('Ace::Object')) {
      $suffix = 'gif';
      ($img,$boxes) = $gd->asGif(@_);
    } else {
      $suffix   = $gd->can('png') ? 'png' : 'gif';
      $img     = $gd->can('png') ? $gd->png : $gd->gif;
    }
    my $basename = md5_hex($img);
    my $dirs = substr($basename,0,6) ;
    $dirs    =~ s!^(.{2})(.{2})(.{2})!$1/$2/$3!g;
    my $path = $self->tmp_image_dir($dirs)."/$basename.$suffix";
    unless(-s $path) {
      open (F,">$path") ;
      print F $img;
      close F;
    }
    my $data = { description => 'The homology image of the protein',
		 data        => "$dirs/$basename.$suffix",
    }; 
    return $data;
}

sub motif_homologies {
    my $self = shift;
    my (%motif);
    my %hash;
    my @row;
    foreach (@{$self ~~ '@Motif_homol'}) {
      my $title = $_->Title;
      my ($database,$description,$accession) = $_->Database->row if $_->Database;
      $hash{database}{$_} = $database;
      $hash{description}{$_} = $title||$_;
      $hash{accession}{$_} = $_;
    }
    my $data = { description => 'The motif summary of the protein',
		 data        => \%hash,
    }; 
    return $data;
}	  
	

sub motif_details {
    my $self = shift;
    my $obj = $self->object;
    my $seq   = $self->cds->[0];
    
    my @raw_features = $self ~~ '@Feature';
    my @motif_homol = $self ~~ '@Motif_homol';
    
    #  return unless $obj->Feature;
    
    print br();
    print a({-name=>'motif_sum'}, "");
    
    # Summary by Motif
    my @tot_positions;
    
    if (@raw_features > 0 || @motif_homol > 0) {
	my %positions;
	foreach my $feature (@raw_features) {
	    %positions = map {$_ => $_->right(1)} $feature->col;
	    foreach my $start (sort {$a <=> $b} keys %positions) {			
		push @tot_positions,{ feature => $feature,
				      start   => $start,
				      stop    => $positions{$start},
				      range   => $start."_to_".$positions{$start}  ### add range to total position
				  };
	    }
	}
	
	# Now deal with the motif_homol features
	foreach my $feature (@motif_homol) {
	    my $score = $feature->right->col;

	    my $start = $feature->right(3);
	    my $stop  = $feature->right(4);
	    my $type = $feature->right;
	    $type  ||= 'Interpro' if $feature =~ /IPR/;
	    (my $accession = $feature) =~ s/^[^:]+://;
	    my $label = "$type&nbsp;$accession";
	    my $link = make_ext_link($feature,$label);

	    # Are the multiple occurences of this feature?
	    my @multiple = $feature->right->right->col;
	    if (@multiple > 1) {
		foreach my $start (@multiple) {
		    my $stop = $start->right;
		    push @tot_positions,{ feature => $link,
					  start   => $start,
					  stop    => $stop,
					  range   => $start."_to_".$stop  ### add range to total position
				      };
		}
	    } else {
		push @tot_positions,{ feature => $link,
				      start   => $start,
				      stop    => $stop,
				      range   => $start."_to_".$stop  ### add range to total position
				  };
	    }

	}

	print start_table({-border =>1, -width=>'100%'});
	
	print TR({-class=>'datatitle',-valign=>'top'},
		 th({-colspan=>3},'Motif Details'));
	print TR({-class=>'datatitle',-valign=>'top'},
		 th('Feature'),
		 th('Start'),
		 th('End'));
	

	
	foreach my $feature (sort {$a->{start} <=> $b->{start} } @tot_positions) 
	{
	    # Print the by Motif table
	    print TR({-class=>'databody'},
		     td($feature->{feature}),
		     td($feature->{start}),
		     td($feature->{stop}));
	}
	
	
	print end_table;
    }
    return;
}

############################################################
#
# The Molecular Details widget
#
############################################################

sub protein_sequence {
    my $self = shift;
    my $peptide = $self->peptide;
    my $data = { description => 'The peptide sequence of the protein',
		 data        => { 'seq' => $peptide ,
				  'length' => length $peptide,
				}
    }; 
    return $data;
}
 

sub estimated_molecular_weight{
    my $self = shift;
    my $data = { description => 'The estimated molecular weight of the protein',
		 data        =>  $self ~~ 'Molecular_weight' ,
    }; 
    return $data;
}

sub estimated_isoelectric_point{
    my $self = shift;
  
    my $pic     = pICalculator->new();
    my $seq     = Bio::PrimarySeq->new($self->peptide);
    $pic->seq($seq);
    my $iep     = $pic->iep;
    my $data = { description => 'The estimated isoelectric point of the protein',
		 data        =>  $iep,
    }; 
    return $data;
}

sub amino_acid_composition{
    my $self = shift;
    return unless($self->peptide);
    my $selenocysteine_count =  (my $hack_seq = $self->peptide)  =~ tr/Uu/Cc/;  # primaryseq doesn't like selenocysteine, so make it a cysteine
    my $seq     = Bio::PrimarySeq->new($hack_seq);
    my $stats   = Bio::Tools::SeqStats->new($seq);

    my %abbrev = (A=>'Ala',R=>'Arg',N=>'Asn',D=>'Asp',C=>'Cys',E=>'Glu',
		Q=>'Gln',G=>'Gly',H=>'His',I=>'Ile',L=>'Leu',K=>'Lys',
		M=>'Met',F=>'Phe',P=>'Pro',S=>'Ser',T=>'Thr',W=>'Trp',
		Y=>'Tyr',V=>'Val',U=>'Sec*',X=>'Xaa');
    # Amino acid content
    my $composition = $stats->count_monomers;
    if ($selenocysteine_count > 0) {
      $composition->{C} -= $selenocysteine_count;
      $composition->{U} += $selenocysteine_count;
    }
    my %aminos = map {$abbrev{$_}=>$composition->{$_}} keys %$composition;
    my $data = { description => 'The amino acid composition of the protein',
		 data        =>  \%aminos ,
    }; 
    return $data;
}


 
############################################################
#
# The Protein History widget, this is actaully on a field level but not widget
#
############################################################
sub history{
    my $self = shift;
   
    my %history ;
    foreach my $obj (@{$self ~~ '@History'}) {
	  my ($status,$prediction) = $obj->row(1);
	  $history{version}{$obj}=$obj;
	  $history{status}{$obj}=$status;
	  $history{prediction}{$obj}=$prediction;
    }
    
    my $data = { description => 'The history information of the protein',
		 data        =>  \%history ,
    }; 
    return $data;
}

 

############################################################
#
# PRIVATE METHODS
#
############################################################

sub _draw_image {
  my $self = shift;
  my $obj = shift;
  my $best_only = shift;

  # Get out the length;
  my $length = length($self->peptide);

  # Setup the panel, using the protein length to establish the box as a guide
  my $ftr = 'Bio::Graphics::Feature';
  my $segment = $ftr->new(-start=>1,-end=>$length,
			  -name=>$obj,
			  -type=>'Protein');

  my $panel = Bio::Graphics::Panel->new(-segment   =>$segment,
					-key       =>'Protein Features',
					-key_style =>'between',
					-key_align =>'left',
					-grid      => 1,
					-width     =>'650');

  # Get out the gene - will use to extract the exons, then map them
  # onto the protein backbone.
  my $gene    = $self->cds->[0];
  my @exons;
  
  my $gffdb = $self->gff_dsn();
  my ($seq_obj) = $gffdb->dbh->segment(CDS => $gene);
  @exons = $seq_obj->features('exon:curated') if $seq_obj;
  @exons = grep { $_->name eq $gene } @exons;

  # Translate the bp start and stop positions into the approximate amino acid
  # contributions from the different exons.
  my ($count,$end_holder);
  my @segmented_exons;
#   local $^W = 0;  # kill uninitialized variable warning
  $end_holder=0;
  foreach my $exon (sort { $a->start <=> $b->start } @exons) {

    $count++;
    my $start = $exon->start;
    my $stop  = $exon->stop;

    # Calculate the difference of the start and stop to figure
    # to figure out how many amino acids it corresponds to
    my $length = (($stop - $start) / 3);
    
    my $end = $length + $end_holder;
    my $seg = $ftr->new(-start=>$end_holder,-end=>$end,
			-name=>"exon $count",-type=>'exon');
    push @segmented_exons,$seg;
    $end_holder = $end;
  }
  

  ## Structural motifs (this returns a list of feature types)
  my %features;
  my @features = $obj->Feature;
  # Visit each of the features, pushing into an array based on its name
  foreach my $type (@features) {
    # 'Tis dangereaux - could lose some features if the keys overlap...
    my %positions = map {$_ => $_->right(1)} $type->col;
    foreach my $start (keys %positions) {
      my $seg   = $ftr->new(-start=>$start,-end=>$positions{$start},
			    -name=>"$type",-type=>$type);
      # Create a hash of all the features, keyed by type;
      push (@{$features{'Features-' . $type}},$seg);
    }
  }
  
  ## A protein ruler
  $panel->add_track(arrow => [ $segment ],
  		    -label => 'amino acids',
		    -arrowstyle=>'regular',
		    -tick=>5,
  		    #		    -tkcolor => 'DarkGray',
  		   );
  
  ## Print the exon boundaries
  $panel->add_track(generic=>[ @segmented_exons ],
		    -glyph     => 'generic',
		    -key       => 'exon boundaries',
		    -bump      => 0,
		    -height    => 6,
		    -spacing   => 50,
		    -linewidth =>1,
		    -connector =>'none',
		   ) if @segmented_exons;

  my %glyphs = (low_complexity => 'generic',
		transmembrane   => 'generic',
		signal_peptide  => 'generic',
		tmhmm           => 'generic'
	       );
  
  my %labels   = ('low_complexity'       => 'Low Complexity',
		  'transmembrane'         => 'Transmembrane Domain(s)',
		  'signal_peptide'        => 'Signal Peptide(s)',
		  'tmhmm'                 => 'Transmembrane Domain(s)',
		  'wublastp_ensembl'      => 'BLASTP Hits on Human ENSEMBL database',
		  'wublastp_fly'          => 'BLASTP Hits on FlyBase database',
		  'wublastp_slimSwissProt'=> 'BLASTP Hits on SwissProt',
		  'wublastp_slimTrEmbl'   => 'BLASTP Hits on Uniprot',
		  'wublastp_worm'         => 'BLASTP Hits on WormPep',
		 );
  
  my %colors   = ('low_complexity' => 'blue',
		  'transmembrane'  => 'green',
		  'signalp'        => 'gray',
		  'prosite'        => 'cyan',
		  'seg'            => 'lightgrey',
		  'pfam'           => 'wheat',
		  'motif_homol'    => 'orange',
		  'wublastp_remanei'      => 'blue'
		 );
  
  foreach ($obj->Homol) {
    my (%partial,%best);
    my @hits = $obj->get($_);
	my %motif_ranges = ();
	
    # Pep_homol data structure is a little different
    if ($_ eq 'Pep_homol') {
      my @features = wrestle_blast(\@hits,1);

      # Sort features by type.  If $best_only flag is true, then we only keep the
      # best ones for each type.
      my %best;
      for my $f (@features) {
	next if $f->name eq $obj;
	my $type = $f->type;
	if ($best_only) {
	  next if $best{$type} && $best{$type}->score > $f->score;
	  $best{$type} = $f;
	} else {
	  push @{$features{'BLASTP Homologies'}},$f;
	}
      }

      # add descriptive information for each of the best ones
#       local $^W = 0; #kill uninit variable warning
      for my $feature ($best_only ? values %best : @{$features{'BLASTP Homologies'}}) {
	my $homol = $HIT_CACHE{$feature->name};
	my $species =  $homol->Species||"";
	my $description = $species;
	my $score       = sprintf("%7.3G",10**-$feature->score);
	$description    =~ s/^(\w)\w* /$1. /;
	$description   .= " ";
# 	my $desc= $homol->Description} || $homol->Gene_name || "";
	$description   .= $homol->Description || $homol->Gene_name || "";
	$description   .=  $homol->Corresponding_CDS->Brief_identification ||""
	  if $species =~ /elegans|briggsae/;
	my $t = $best_only ? "best hit, " : '';
	$feature->desc("$description (${t}e-val=$score)") if $description;
      }

      if ($best_only) {
	for my $type (keys %best) {
	  push @{$features{'Selected BLASTP Homologies'}},$best{$type};
	}
      }

      # these are other homols
    } else {	
      for my $homol (@hits) {
	my $title = eval {$homol->Title};
	my $type  = $homol->right or next;
	my @coord = $homol->right->col;
	my $name  = $title ? "$title ($homol)" : $homol;
	
	### filter out duplicate segments ####
	foreach my $segment (@coord) {
	my ($start,$stop) = $segment->right->row;
	my $range = $start."_to_".$stop;
	

	if ($motif_ranges{$range}){
	   next;
	}
	 else{
	     my $seg  = $ftr->new(-start=>$start,
			       -end =>$stop,
			       -name =>$name,
			       -type =>$type);
	     push (@{$features{'Motifs'}},$seg);
	     # print "<pre>$range</pre>"; 
	     $motif_ranges{$range} = 1;;
	}
   }
      }
    }
  }

  
  foreach my $key (sort keys %features) {
    # Get the glyph
    my $type  = $features{$key}[0]->type;
    
    my $label = $labels{$key}  || $key;
    my $glyph = $glyphs{$key}  || 'graded_segments';
    my $color = $colors{lc($type)} || 'green';
    my $connector = $key eq 'Pep_homol' ? 'solid' : 'none';
     $self->log->debug("aaaaaaaaaaaaaaaaa $type $label $key");
    $panel->add_track(segments     => $features{$key},
		      -glyph       => $glyph,
		      -label       => ($label =~ /Features/) ? 0 : 1,
		      -bump        => 1,
		      -sort_order  => 'high_score',
		      -bgcolor     => $color,
		      -font2color  => 'red',
		      -height      => 6,
		      -linewidth   => 1,
		      -description => 1,
		      -min_score   => -50,
		      -max_score   => 100,
		      -key         => $label,
		      -description => 1,
		     );
  }
  
  return $panel;

}
sub wrestle_blast {
  my $hits = shift;
  my $as_features = shift;

  my (@hits,%cached_features);
  my %seen;
  for my $homol (@$hits) {
    for my $type ($homol->col) {
      for my $score ($type->col) {
	for my $start ($score->col) {
	  for my $end ($start->col) {
	    my ($tstart,$tend) = $end->row(1);

	    next if ($seen{"$start$end$homol"}++);

	    $HIT_CACHE{$homol} = $homol;

	    if ($as_features) {
	      my $f = $cached_features{$type}{$homol};
	      if (!$f) {
		$f
		  = $cached_features{$type}{$homol}
		    = Bio::Graphics::Feature->new(-name     => "$homol",   # quotes and +0 stringifies ace object
						  -type     => "$type",
						  -score    => $score+0);
		push @hits,$f;
	      }
	      $f->add_segment(Bio::Graphics::Feature->new(-start => $start+0,
							  -end   => $end+0,
							  -score => $score+0,
							 ));
	    } else {
	      push @hits,{hit=>$homol,type=>$type,score=>$score,source=>"$start..$end",target=>"$tstart..$tend"};
	    }
	  }
	}
      }
    }
  }
  @hits;
}


1;
