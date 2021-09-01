package Mojolicious::Plugin::Component;

use Mojo::Base 'Mojolicious::Plugin';

use File::Spec::Functions qw(catdir splitdir);

use File::Find;

use Module::Load;

sub register
{
	my($self, $app, $conf) = @_;
	
	my $namespace = $conf->{namespace} ||= ref $app;
	
	my $ignore    = $conf->{ignore};
	
	my $action    = $conf->{action}    ||= 'component';
	
	my $maxdepth  = $conf->{maxdepth}  ||= 10;
	
	my $quiet     = $conf->{quiet};
	
	my $debug     = $conf->{debug};
	
	my $depth = split('::', $namespace);
	
	my $lib   = catdir($app->home, 'lib');
	
	my $path  = catdir($lib, split('::', $namespace));
	
	
	return unless -d $path;
	
	
	my %modules;

	my $wanted = sub
	{
		return unless /\.pm$/;
		
		my $filepath = $File::Find::name;
		
		$filepath =~ s/\Q$lib\E[\\\/]//;
		
		$filepath =~ s/\.pm$//;
		
		my @dir = splitdir($filepath);
		
		my $package = join('::', @dir);
		
		if(((scalar @dir) - $depth) <= $maxdepth)
		{
			my $key = $package;
			
			$key =~ s/^\Q$namespace\E:://;
			
			$modules{$key} = $package;
		}
	};
	
	find($wanted, $path);
	
	my %blacklist;
	
	my %map;
	
	if($ignore && ref $ignore eq 'ARRAY')
	{
		%blacklist = map { $_ => 1 } @{ $ignore };
	}
	
	while(my($key, $module) = each %modules)
	{
		next if $blacklist{$key};
		
		eval { load($module) };
		
		next unless $module->can('new');
		
		$map{$key} = $module->new({ app => $app });
		
		{ no strict 'refs';
			
			*{ "$module\::app" }      = sub { $app };
			
			*{ "$module\::$action" }  = sub { $map{$_[1]} };
			
			*{ "$module\::AUTOLOAD" } = sub { '' } if $quiet;
		}
	}
	
	$app->helper($action => sub
		{
			$map{$_[1]} || ( $quiet ? ( __PACKAGE__ .'::Blank' )->new : undef );
		}
	);
}


package Mojolicious::Plugin::Component::Blank;


sub new { bless {}, shift }


sub AUTOLOAD { '' }


1;
