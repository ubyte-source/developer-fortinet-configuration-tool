# Documentation developer-fortinet-configuration-tool

Tool bash to create configuration files fot Fortinet ISA99

## Usage

So the basic setup looks something like this:

```bash

./fortinet.sh -e <account@energia-europa.com> -p <password> -m <MAC-address> -s <serial-number> > output.zip

// optional you use -d parameter for duplicate existing configuration by ID es. -d 77

```

## Structure

library:
- [fortinet.sh](https://github.com/energia-source/developer-fortinet-configuration-tool)

## Built With

* [BASH](https://www.gnu.org/software/bash/) - BASH

## Contributing

Please read [CONTRIBUTING.md](https://github.com/energia-source/developer-fortinet-configuration-tool/blob/main/CONTRIBUTING.md) for details on our code of conduct, and the process for submitting us pull requests.

## Versioning

We use [SemVer](https://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/energia-source/developer-fortinet-configuration-tool/tags). 

## Authors

* **Paolo Fabris** - *Initial work* - [energia-europa.com](https://www.energia-europa.com/)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details
