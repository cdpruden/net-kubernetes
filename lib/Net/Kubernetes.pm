package Net::Kubernetes;
# ABSTRACT: An object oriented interface to the REST API's provided by kubernetes

use Moose;
require Net::Kubernetes::Namespace;
require LWP::UserAgent;
require HTTP::Request;
require URI;;
require Throwable::Error;
use MIME::Base64;
require Net::Kubernetes::Exception;

=head1 SYNOPSIS

  my $kube = Net::Kubernets->new(url=>'http://127.0.0.1:8080', username=>'dave', password=>'davespassword');
  my $pod_list = $kube->list_pods();
  
  my $nginx_pod = $kube->create_from_file('kubernetes/examples/pod.yaml');
  
  my $ns = $kube->get_namespace('default');
  
  my $services = $ns->list_services;
  
  my $pod = $ns->get_pod('my-pod');
  
  $pod->delete;
  
  my $other_pod = $ns->create_from_file('./my-pod.yaml');

=begin html

<h2>Build Status</h2>

<img src="https://travis-ci.org/perljedi/net-kubernetes.svg?branch=release-0.11" />

=end html

=cut


with 'Net::Kubernetes::Role::APIAccess';
with 'Net::Kubernetes::Role::ResourceLister';


=method new - Create a new $kube object

All parameters are optional and have some basic default values (where appropriate).

=over 1

=item url ['http://localhost:8080']

The base url for the kubernetes. This should include the protocal (http or https) but not "/api/v1beta3" (see base_path).

=item base_path ['/api/v1beta3']

The entry point for api calls, this may be used to set the api version with which to interact.

=item username

Username to use with basic authentication. If either username or password are not provided, basic authentication will not
be used.

=item password

Password to use with basic authentication. If either username or password are not provided, basic authentication will not
be used.

=item token

An authentication token to be used to access the apiserver.  This may be provided as a plain string, a path to a file
from which to read the token (like /var/run/secrets/kubernetes.io/serviceaccount/token from within a pod), or a reference
to a file handle (from which to read the token).

=back

=method get_namespace("myNamespace");

This method returns a "Namespace" object on which many methods can be called implicitly
limited to the specified namespace.

=method get_pod('my-pod-name')

Delegates automatically to L<Net::Kubernetes::Namespace> via $self->get_namespace('default')

=method get_repllcation_controller('my-rc-name') (aliased as $ns->get_rc('my-rc-name'))

Delegates automatically to L<Net::Kubernetes::Namespace> via $self->get_namespace('default')

=method get_service('my-servce-name')

Delegates automatically to L<Net::Kubernetes::Namespace> via $self->get_namespace('default')

=method get_secret('my-secret-name')

Delegates automatically to L<Net::Kubernetes::Namespace> via $self->get_namespace('default')

=cut

has 'default_namespace' => (
	is         => 'rw',
	isa        => 'Net::Kubernetes::Namespace',
	required   => 0,
	lazy       => 1,
	handles    => [qw(get_pod get_rc get_replication_controller get_secret get_service create create_from_file build_secret)],
	builder    => '_get_default_namespace',
);

sub get_namespace {
	my($self, $namespace) = @_;
	if (! defined $namespace || ! length $namespace) {
		Throwable::Error->throw(message=>'$namespace cannot be null');
	}
	my $res = $self->ua->request($self->create_request(GET => $self->path.'/namespaces/'.$namespace));
	if ($res->is_success) {
		my $ns = $self->json->decode($res->content);
		my(%create_args) = (url => $self->url, base_path=>$ns->{metadata}{selfLink}, namespace=> $namespace, _namespace_data=>$ns);
		$create_args{username} = $self->username if(defined $self->username);
		$create_args{password} = $self->password if(defined $self->password);
		return Net::Kubernetes::Namespace->new(%create_args);
	}else{
		Net::Kubernetes::Exception->throw(code=>$res->code, message=>"Error getting namespace $namespace:\n".$res->message);
	}
}

sub _get_default_namespace {
	my($self) = @_;
	return $self->get_namespace('default');
}

# SEEALSO: Net::Kubernetes::Namespace, Net::Kubernetes::Resource

return 42;
