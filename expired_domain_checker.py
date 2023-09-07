import tldextract
import whois
import datetime
import socket

class DomainChecker:
    def __init__(self, filename, debug=False):
        # Initialize the DomainChecker with the input file name and debug flag
        self.filename = filename
        self.unique_domains = set()
        self.debug = debug

    def extract_unique_domains(self):
        # Method to extract unique domains from the input file
        if self.debug:
            print("Extracting unique domains...")

        with open(self.filename, 'r') as file:
            for line in file:
                domain = line.strip()
                main_domain = self.extract_main_domain(domain)
                self.unique_domains.add(main_domain)

        if self.debug:
            print(f"Unique domains: {self.unique_domains}")

    @staticmethod
    def extract_main_domain(domain):
        # Static method to extract the main domain from a given domain
        extracted = tldextract.extract(domain)
        return f"{extracted.domain}.{extracted.suffix}"

    def get_domain_expiration_date(self, domain):
        # Method to fetch the expiration date of a domain using whois
        if self.debug:
            print(f"Fetching expiration date for domain: {domain}...")

        try:
            domain_info = whois.whois(domain)
            expiration_date = domain_info.expiration_date
            if isinstance(expiration_date, list):
                expiration_date = min(expiration_date)

            if self.debug:
                print(f"Expiration date for domain {domain}: {expiration_date}")

            return expiration_date
        except whois.parser.PywhoisError as e:
            if "Name or service not known" in str(e):
                # Handle the "Name or service not known" error
                if self.debug:
                    print(f"Failed to fetch expiration date for domain: {domain}")
                    print(f"Error: {str(e)}")
                return None
            else:
                # Handle other whois-related errors
                if self.debug:
                    print(f"Failed to fetch expiration date for domain: {domain}")
                    print(f"Other error: {str(e)}")
                return None
        except socket.gaierror as e:
            # Handle socket errors (e.g., "Name or service not known")
            if self.debug:
                print(f"Failed to connect to socket for domain: {domain}")
                print(f"Socket error: {str(e)}")
            return None

    def find_expired_domains(self):
        # Method to find expired domains among the unique domains
        today = datetime.datetime.now()
        expired_domains = []

        if self.debug:
            print("Finding expired domains...")

        for domain in self.unique_domains:
            expiration_date = self.get_domain_expiration_date(domain)
            if expiration_date and expiration_date < today:
                expired_domains.append((domain, expiration_date))

        return expired_domains

    @staticmethod
    def print_large_warning(message):
        print("\033[91m" + "="*50)
        print(message)
        print("="*50 + "\033[0m")

if __name__ == "__main__":
    # Create an instance of the DomainChecker class with the input file and debug flag
    checker = DomainChecker('domains.txt', debug=True)

    # Extract unique domains from the input file
    checker.extract_unique_domains()

    # Find and store expired domains
    expired_domains = checker.find_expired_domains()

    if expired_domains:
        # Print expired domains and their expiration dates with a warning message
        checker.print_large_warning("WARNING: The following domains have expired:")
        for domain, expiration_date in expired_domains:
            print(f"Domain: {domain}, Expiration Date: {expiration_date}")
    else:
        # If no expired domains are found, print a message
        print("No expired domains found.")
