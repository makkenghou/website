#!/usr/bin/env perl

# This is a unit test template for implementing tests that work
# with a running WormBase Website instance.
#
# Unit tests are called automagically, just adhere to the following:
#
# 1. the unit test is placed in the t/api_tests folder
# 2. the filename and package name coincide (sans suffix)
# 3. unit test names have the prefix "test_"
#
# Actual tests are implemented at the bottom of this file. Please see:
#
# 1. test_single_gene

{
    # Package name is the same as the filename (sans suffix, i.e. no .t ending)
    package disease;

    # Limit the use of unsafe Perl constructs.
    use strict;

    # We use Test::More for all tests, so include that here.
    use Test::More;

    # This variable will hold a reference to a WormBase API object.
    my $api;

    # A setter method for passing on a WormBase API object from t/api.t to
    # the subs of this package.
    sub config {
        $api = $_[0];
    }

    sub test_disease_genes_by_biology {
        #my $disease = $api->fetch({ class => 'Disease', name => 'achondrogenesis type IB' });
        my $disease = $api->fetch({ class => 'Disease', name => 'DOID:9970' });
        
        # Test if the object contains this method
        can_ok('WormBase::API::Object::Disease', ('genes_biology'));
        
        #my $longest = $gene->_longest_segment;
        #isnt($longest, undef, 'data returned');
        
        my $genes_biology = $disease->genes_biology;
        isnt( $genes_biology, undef, "data returned");
        
        my $genes_by_biology = $genes_biology->{data};
        is( ref $genes_by_biology, 'ARRAY', "data contains array reference");
        
        # This object should have 8 genes by biology
        is(scalar @$genes_by_biology, 4, 'correct number of genes by biology');
    }
    

}

1;

