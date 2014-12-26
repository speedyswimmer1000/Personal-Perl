 #!/usr/bin/perl
  use strict;
  use Email::Send;
  use Email::Send::Gmail;
  use Email::Simple::Creator;
  
  my @args = @ARGV;
  our $message = join(' ', @args);
  print $message;

  my $email = Email::Simple->create(
      header => [
          From    => 'benjamin.lewis.1000@gmail.com',
          To      => 'speedyswimmer1000@gmail.com',
          Subject => 'Perl Script Message',
      ],
      body => $message,
  );

  my $sender = Email::Send->new(
      {   mailer      => 'Gmail',
          mailer_args => [
              username => 'benjamin.lewis.1000@gmail.com',
              password => '### Replace here!',
          ]
      }
  );
  eval { $sender->send($email) };
  die "Error sending email: $@" if $@;