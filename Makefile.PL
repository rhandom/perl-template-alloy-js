use ExtUtils::MakeMaker;

###----------------------------------------------------------------###
#  Copyright 2011 - Paul Seamons                                     #
#  Distributed under the same terms as Perl itself                   #
###----------------------------------------------------------------###

WriteMakefile(
              NAME          => "Template::Alloy::JS",
              AUTHOR        => "Paul Seamons",
              ABSTRACT_FROM => "lib/Template/Alloy/JS.pod",
              VERSION_FROM  => "lib/Template/Alloy/JS.pm",
              INSTALLDIRS   => 'site',
              PREREQ_PM     => {
                  'Digest::MD5' => 1,
                  'JavaScript::V8' => 1,
                  'JSON'           => 1,
              },
              dist          => {
                  DIST_DEFAULT => 'all tardist',
                  COMPRESS     => 'gzip -vf',
                  SUFFIX       => '.gz',
              },
              clean          => {
                  FILES        => '*~',
              },
              realclean         => {
                  FILES        => '*~',
              },
              );

package MY;

sub postamble {
  return qq^

pm_to_blib: README

README: lib/Template/Alloy/JS.pod
	pod2text lib/Template/Alloy/JS.pod > README
^;
}

1;
