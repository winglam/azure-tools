import java.util.Map;
import java.util.HashMap;

import java.io.File;
import java.io.StringWriter;
import java.io.PrintWriter;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.BufferedReader;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;

import org.w3c.dom.Document;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

import org.xml.sax.SAXException;

import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.TransformerException;
import javax.xml.transform.OutputKeys;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;

public class PomFile {

    private String pom;
    private String fullPath;
    private String artifactId;

    static String userHome = System.getProperty("user.home");

    public PomFile(String pom) {
        this.pom = pom;
        try {
            this.fullPath = new File(pom).getParentFile().getCanonicalPath();
        } catch (IOException e) {
            e.printStackTrace();
        }

        // Parse document for projectId
        findProjectId(pom);
    }

    public static Node getDirectChild(Node parent, String name)
    {
        for(Node child = parent.getFirstChild(); child != null; child = child.getNextSibling())
            {
                if(child instanceof Node && name.equals(child.getNodeName())) return child;
            }
        return null;
    }

    private void findProjectId(String pom) {
        File pomFile = new File(pom);
        DocumentBuilderFactory dbFactory = DocumentBuilderFactory
            .newInstance();
        dbFactory.setNamespaceAware(false);
        dbFactory.setValidating(false);
        DocumentBuilder dBuilder;

        try {

            dBuilder = dbFactory.newDocumentBuilder();
            Document doc = dBuilder.parse(pomFile);

            // Find high-level artifact Id
            Node project = doc.getElementsByTagName("project").item(0);
            NodeList projectChildren = project.getChildNodes();
            for (int i = 0; i < projectChildren.getLength(); i++) {
                Node n = projectChildren.item(i);

                if (n.getNodeName().equals("artifactId")) {
                    this.artifactId = n.getTextContent();
                }
            }

        } catch (ParserConfigurationException e) {
            e.printStackTrace();
        } catch (SAXException e) {
            e.printStackTrace();
        } catch (FileNotFoundException e) {
            System.out.println("File does not exit: " + pom);
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    // Rewrite contents of own pom.xml, augmented with information
    // about dependency srcs and dependency outputs
    public void rewrite() {
        File pomFile = new File(this.pom);
        DocumentBuilderFactory dbFactory = DocumentBuilderFactory
            .newInstance();
        dbFactory.setNamespaceAware(false);
        dbFactory.setValidating(false);
        DocumentBuilder dBuilder;

        try {
            dBuilder = dbFactory.newDocumentBuilder();
            Document doc = dBuilder.parse(pomFile);

            // Find the <project> node (should only be one)
            if (doc.getElementsByTagName("project").getLength() > 1) {
                throw new ParserConfigurationException();
            }
            Node project = doc.getElementsByTagName("project").item(0);
            NodeList projectChildren = project.getChildNodes();

            // Check if <build> tag under <project> exists; if not have to make one
            Node build = null;
            for (int i = 0; i < projectChildren.getLength(); i++) {
                if (projectChildren.item(i).getNodeName().equals("build")) {
                    // Make sure it is directly under this <project> tag
                    if (projectChildren.item(i).getParentNode().equals(project)) {
                        build = projectChildren.item(i);
                        break;
                    }
                }
            }
            if (build == null) {
                build = doc.createElement("build");
                doc.getElementsByTagName("project").item(0).appendChild(build);
            }
            NodeList buildChildren = build.getChildNodes();

            // Search for <plugins>
            Node plugins = null;
            for (int i = 0; i < buildChildren.getLength(); i++) {
                if (buildChildren.item(i).getNodeName().equals("plugins")) {
                    plugins = buildChildren.item(i);
                    break;
                }
            }
            // Add new <plugins> if non-existant
            if (plugins == null) {
                plugins = doc.createElement("plugins");
                build.appendChild(plugins);
            }

            // Look for Surefire plugin, add if necessary
            NodeList pluginsChildren = plugins.getChildNodes();
            Node surefirePlugin = null;
            for (int i = 0; i < pluginsChildren.getLength(); i++) {
                Node plugin = pluginsChildren.item(i);
                NodeList pluginChildren = plugin.getChildNodes();
                boolean found = false;
                for (int j = 0; j < pluginChildren.getLength(); j++) {
                    Node tmp = pluginChildren.item(j);
                    if (tmp != null && tmp.getNodeName().equals("artifactId") && tmp.getTextContent().equals("maven-surefire-plugin")) {
                        found = true;
                        break;
                    }
                }
                // Found a Surefire plugin
                /*if (found) {
                    surefirePlugin = plugin;
                    // Update the configuration for the argLine
                    NodeList surefirePluginChildren = surefirePlugin.getChildNodes();
                    Node config = null;
                    for (int j = 0; j < surefirePluginChildren.getLength(); j++) {
                        Node tmp = pluginChildren.item(j);
                        if (tmp != null && tmp.getNodeName().equals("configuration")) {
                            config = tmp;
                            break;
                        }
                    }
                    if (config == null) {
                        config = doc.createElement("configuration");
                        surefirePlugin.appendChild(config);
                    }
                    extendBasicPlugin(doc, config);
                    break;
                }*/
            }
            // It's missing, so make a new one (that already has the configuration updated) and add
            if (surefirePlugin == null) {
                surefirePlugin = makeSurefirePlugin(doc);
                plugins.appendChild(surefirePlugin);

            }

                {
					Node plugin = doc.createElement("plugin");
					{
						Node groupId = doc.createElement("groupId");
						groupId.setTextContent("edu.illinois");
						plugin.appendChild(groupId);
					}
					{
						Node artifactId = doc.createElement("artifactId");
						artifactId.setTextContent("nondex-maven-plugin");
						plugin.appendChild(artifactId);
					}
					{
						Node version = doc.createElement("version");
						version.setTextContent("1.1.2");
						plugin.appendChild(version);
					}
					
					plugins.appendChild(plugin);
				}
            doc.normalizeDocument();
            // Construct string representation of the file
            TransformerFactory tf = TransformerFactory.newInstance();
            Transformer transformer = tf.newTransformer();
            transformer.setOutputProperty(OutputKeys.OMIT_XML_DECLARATION, "yes");
            transformer.setOutputProperty(OutputKeys.INDENT, "yes");
            transformer.setOutputProperty("{http://xml.apache.org/xslt}indent-amount", "2");
            StringWriter writer = new StringWriter();
            transformer.transform(new DOMSource(doc), new StreamResult(writer));
            String output = writer.getBuffer().toString();

            // Rewrite the pom file with this string
            PrintWriter filewriter = new PrintWriter(this.pom);
            filewriter.println(output);
            filewriter.close();
        } catch (ParserConfigurationException e) {
            e.printStackTrace();
        } catch (SAXException e) {
            e.printStackTrace();
        } catch (FileNotFoundException e) {
            System.out.println("File does not exit: " + this.pom);
        } catch (IOException e) {
            e.printStackTrace();
        } catch (TransformerException e) {
            e.printStackTrace();
        }
    }

    private void createExcludesFileElement(Document doc, Node plugin) {
        Node excludesFile;
        excludesFile = doc.createElement("excludesFile");
        excludesFile.setTextContent("myExcludes");
        plugin.appendChild(excludesFile);
    }

    private Node makeSurefirePlugin(Document doc) {
        Node surefirePlugin;
        Node config;

        surefirePlugin = doc.createElement("plugin");
        createBasicPlugin(doc, surefirePlugin);
        /*config = doc.createElement("configuration");
        extendBasicPlugin(doc, config);
        surefirePlugin.appendChild(config);*/
        return surefirePlugin;
    }

    private void extendBasicPlugin(Document doc, Node config) {
        createArgLineElement(doc, config);
    }

    private void createArgLineElement(Document doc, Node config) {
        Node argLine;
        argLine = doc.createElement("argLine");
        config.appendChild(argLine);
    }

    private void createBasicPlugin(Document doc, Node surefirePlugin) {
        Node groupID;
        Node artifactID;
        Node version;
        Node excludesFile;

        groupID = doc.createElement("groupId");
        groupID.setTextContent("org.apache.maven.plugins");
        surefirePlugin.appendChild(groupID);

        artifactID = doc.createElement("artifactId");
        artifactID.setTextContent("maven-surefire-plugin");
        surefirePlugin.appendChild(artifactID);

        /*version = doc.createElement("version");
        version.setTextContent("2.19");
        surefirePlugin.appendChild(version);*/
    }

    // Accessors
    public String getFullPath() {
        return this.fullPath;
    }

    public String getArtifactId() {
        return this.artifactId;
    }

    public static void main(String[] args) {
        InputStreamReader isReader = new InputStreamReader(System.in);
        BufferedReader bufReader = new BufferedReader(isReader);
        Map<String,PomFile> mapping = new HashMap<String,PomFile>();
        String input;
        try {
            // TODO(Owolabi): This while loop needs to go?
            // First create objects out of all the pom.xml files passed in
            PomFile p; // = new PomFile(input);
            while ((input = bufReader.readLine()) != null) {
                if ( args.length > 0 && args[0] != null){
                    p = new PomFile(input);
                } else {
                    p = new PomFile(input);
                }
                mapping.put(p.getArtifactId(), p);
            }

            // Go through all the objects and have them rewrite themselves using information from
            // dependencies
            for (Map.Entry<String,PomFile> entry : mapping.entrySet()) {
                PomFile p2 = entry.getValue();

                // Have the object rewrite itself (the pom) with mop stuff
                p2.rewrite();
            }
        } catch(IOException e) {
            e.printStackTrace();
        }
    }
}

