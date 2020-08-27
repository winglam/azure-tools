package fun.jvm.archaeology;

import org.eclipse.jdt.core.JavaCore;
import org.eclipse.jdt.core.dom.*;
import org.eclipse.jgit.api.Git;
import org.eclipse.jgit.api.errors.GitAPIException;
import org.eclipse.jgit.diff.DiffEntry;
import org.eclipse.jgit.diff.DiffFormatter;
import org.eclipse.jgit.diff.RenameDetector;
import org.eclipse.jgit.errors.MissingObjectException;
import org.eclipse.jgit.lib.*;
import org.eclipse.jgit.revwalk.RevCommit;
import org.eclipse.jgit.revwalk.RevWalk;
import org.eclipse.jgit.storage.file.FileRepositoryBuilder;
import org.eclipse.jgit.treewalk.CanonicalTreeParser;
import org.eclipse.jgit.treewalk.TreeWalk;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class TestHistoryCrawler {
    public static void main(String[] args) throws IOException, GitAPIException, InterruptedException {
//        String gitDir = "/Users/jon/Documents/GMU/Projects/firstShaFlaky/experiments/wikidata-wikidata-toolkit/.git";
//        String testToFind = "org.wikidata.wdtk.dumpfiles.wmf.WmfOnlineStandardDumpFileTest#downloadNoRevisionId";

        ExecutorService executorService = Executors.newFixedThreadPool(Runtime.getRuntime().availableProcessors());
        System.out.println(Runtime.getRuntime().availableProcessors());
        try (Scanner scanner = new Scanner(new File("id_flakies_tests.csv"))) {
            while (scanner.hasNextLine()) {
                String[] d = scanner.nextLine().split(",");
                final String gitDir = d[0];
                final String sha = d[1];
                final String testToFind = d[2].substring(0, d[2].lastIndexOf('.')) + "#" + d[2].substring(d[2].lastIndexOf('.') + 1);
                File outputFile = new File("testHistory/" + testToFind);
                if (!outputFile.exists()) {
                    executorService.submit(new Runnable() {
                        @Override
                        public void run() {
                            Repository repo = null;
                            try {
                                repo = new FileRepositoryBuilder().setGitDir(new File(gitDir)).build();
                                TestHistoryCrawler c = new TestHistoryCrawler(repo);
                                c.findTestOverHistory(testToFind, sha);
                                repo.close();
                            } catch (IOException | GitAPIException e) {
                                e.printStackTrace();
                            }
                        }
                    });
                }

            }
        }
        executorService.shutdown();
        executorService.awaitTermination(100, TimeUnit.DAYS);
    }

    RevWalk revWalk;
    Repository repo;
    CanonicalTreeParser thisCommParser = new CanonicalTreeParser();
    CanonicalTreeParser parentParser = new CanonicalTreeParser();

    ObjectReader reader;
    DiffFormatter f = new DiffFormatter(System.out);

    public TestHistoryCrawler(Repository repo) {
        revWalk = new RevWalk(repo);
        this.repo = repo;
        reader = repo.newObjectReader();
    }

    public void findTestOverHistory(String testToFind, String currentRev) throws IOException, GitAPIException {
        ObjectId cur = repo.resolve(currentRev);
        RevCommit commit = null;
        try {
            commit = revWalk.parseCommit(cur);
        } catch (MissingObjectException ex) {
            System.out.println(testToFind + "," + currentRev + ",INVALIDSHA,INVALIDSHA");
            return;
        }
        TreeWalk treeWalk = new TreeWalk(repo);
        treeWalk.addTree(commit.getTree());
        treeWalk.setRecursive(true);
        String classNameToFind = testToFind.substring(0, testToFind.indexOf('#'));
        String methodToFind = testToFind.substring(testToFind.indexOf('#') + 1);
        String packageNameToFind = classNameToFind.substring(0, classNameToFind.lastIndexOf('.'));
        String unqualifiedClassName = classNameToFind.substring(classNameToFind.lastIndexOf('.') + 1);
        String fileNameToFind = unqualifiedClassName + ".java";
        String pathToStart = null;
        String status = null;
        while (treeWalk.next()) {
            if (treeWalk.getPathString().endsWith(fileNameToFind)) {
                ObjectLoader loader = repo.open(treeWalk.getObjectId(0));
                byte[] dat = loader.getBytes();
//                String status =
                status = checkForPackageAndMethod(packageNameToFind, unqualifiedClassName, methodToFind, dat);
                if (status.charAt(0) != '!') {
                    pathToStart = treeWalk.getPathString();
                    break;
                }
                pathToStart = status;
            }
        }
        treeWalk.close();

        if (pathToStart.charAt(0) == '!') {
            throw new IllegalStateException("Unable to find " + testToFind + " in revision" + currentRev + ": " + pathToStart);
        }
        TestHistory history = new TestHistory();
        lineage.put(currentRev, history);
        history.SHA = currentRev;
        history.testName = status;
        LinkedList<CommitCheck> stack = new LinkedList<>();
        for (RevCommit parent : commit.getParents()) {
            stack.add(new CommitCheck(parent, pathToStart, packageNameToFind, unqualifiedClassName, methodToFind));
        }
        while (!stack.isEmpty()) {
            checkCommitForFileWithPossibleRename(stack, stack.pop());
        }
        //Now, go in linear order backwards to order
        Git git = new Git(repo);
        LinkedList<String> commitsInReverseOrder = new LinkedList<String>();
        for (RevCommit c : git.log().add(commit).call()) {
            if (lineage.containsKey(c.name()) && lineage.get(c.name()).testName != null) {
                commitsInReverseOrder.addFirst(c.name());
            }
        }
        int i = 0;
        FileWriter fw = new FileWriter("testHistory/" + testToFind);
        for (String s : commitsInReverseOrder) {
            lineage.get(s).distanceFromFirstCommit = i;
            fw.write(i + "," + s + "," + lineage.get(s).testName + "\n");
            i++;
        }
        fw.close();
        String firstSha = commitsInReverseOrder.getFirst();
        revWalk.close();
        reader.close();
        f.close();
        System.out.println(testToFind + "," + currentRev + "," + lineage.get(firstSha).testName + "," + firstSha);
    }

    HashSet<String> visited = new HashSet<String>();

    HashMap<String, TestHistory> lineage = new HashMap<String, TestHistory>();

    static class CommitCheck {
        RevCommit commit;
        String prevFileName;
        String packageNameToFind;
        String unqualifiedClassName;
        String methodToFind;

        public CommitCheck(RevCommit commit, String prevFileName, String packageNameToFind, String unqualifiedClassName, String methodToFind) {
            this.commit = commit;
            this.prevFileName = prevFileName;
            this.packageNameToFind = packageNameToFind;
            this.unqualifiedClassName = unqualifiedClassName;
            this.methodToFind = methodToFind;
        }
    }

    public void checkCommitForFileWithPossibleRename(List<CommitCheck> stack, CommitCheck job) throws IOException {
        RevCommit commit = job.commit;
        String prevFileName = job.prevFileName;
        String packageNameToFind = job.packageNameToFind;
        String unqualifiedClassName = job.unqualifiedClassName;
        String methodToFind = job.methodToFind;
        if (lineage.containsKey(commit.name())) {
            return;
        }
        TestHistory history = new TestHistory();
        lineage.put(commit.name(), history);
        history.SHA = commit.name();

        commit = revWalk.parseCommit(commit);
        //Check to see if we expect the package name to change by diff'ing against current
        thisCommParser.reset(reader, commit.getTree());
        if (commit.getParentCount() == 0) {
            parentParser.reset();
        } else {
            parentParser.reset(reader, revWalk.parseCommit(commit.getParent(0)).getTree());
        }
        f.setRepository(repo);
        List<DiffEntry> entries = f.scan(parentParser, thisCommParser);
        RenameDetector rd = new RenameDetector(repo);
        rd.addAll(entries);
        entries = rd.compute();

        String fileNameToFind = prevFileName;
        boolean isFirst = false;
        AbbreviatedObjectId objectToCheck = null;
        for (DiffEntry diff : entries) {
            if (diff.getNewPath().equals(prevFileName)) {
                objectToCheck = diff.getNewId();
                if (diff.getChangeType() == DiffEntry.ChangeType.ADD) {
                    if (commit.getParentCount() <= 1) {
                        isFirst = true;
                    }
                }
                if (diff.getChangeType() == DiffEntry.ChangeType.RENAME) {
                    fileNameToFind = diff.getOldPath();
                }
            }
        }
        if (objectToCheck == null) {
            TreeWalk treeWalk = new TreeWalk(repo);
            treeWalk.addTree(commit.getTree());
            treeWalk.setRecursive(true);
            String pathToStart = null;
            while (treeWalk.next()) {
                if (treeWalk.getPathString().endsWith(fileNameToFind)) {
                    objectToCheck = AbbreviatedObjectId.fromObjectId(treeWalk.getObjectId(0));
                }
            }
            treeWalk.close();
            if (objectToCheck == null) {
                return;
            }
        }
        //Get the file contents
        ObjectLoader loader = repo.open(objectToCheck.toObjectId());
        String status = checkForPackageAndMethod(null, unqualifiedClassName, methodToFind, loader.getBytes());
        if (status.charAt(0) != '!') {
            history.testName = status;
            packageNameToFind = status.substring(0, status.lastIndexOf('.'));
            unqualifiedClassName = fileNameToFind.substring(fileNameToFind.lastIndexOf('/') + 1);
            unqualifiedClassName = unqualifiedClassName.substring(0, unqualifiedClassName.lastIndexOf('.'));
        }
        if (!isFirst) {
            for (RevCommit parent : commit.getParents()) {
                stack.add(new CommitCheck(parent, fileNameToFind, packageNameToFind, unqualifiedClassName, methodToFind));
            }
        }
    }

    class TestHistory {
        String SHA;
        String testName;
        int distanceFromFirstCommit;
    }

    public static String checkForPackageAndMethod(String expectedPackageName, String expectedClassName, String expectedMethodName, byte[] clazz) throws UnsupportedEncodingException {
        ASTParser p = ASTParser.newParser(AST.JLS8);
        p.setUnitName(expectedClassName + ".java");
        Map<String, String> options = JavaCore.getOptions();
        JavaCore.setComplianceOptions(JavaCore.VERSION_1_8, options);
        p.setCompilerOptions(options);
        p.setKind(ASTParser.K_COMPILATION_UNIT);
        p.setSource(new String(clazz, "UTF-8").toCharArray()); //TODO fix char encodings
        final CompilationUnit root = (CompilationUnit) p.createAST(null);

        if (expectedPackageName != null && !root.getPackage().getName().toString().equals(expectedPackageName)) {
            return "!WRONG_PACKAGE";
        }
        for (Object o : root.types()) {
            if (o instanceof TypeDeclaration) {
                TypeDeclaration t = (TypeDeclaration) o;
                if (t.getName().toString().equals(expectedClassName)) {
                    for (MethodDeclaration md : t.getMethods()) {
                        if (md.getName().toString().equals(expectedMethodName)) {
                            return root.getPackage().getName() + "." + t.getName() + "#" + md.getName();
                        }
                    }
                    return "!NO_SUCH_METHOD";
                }
            }
        }
        return "!WRONG_CLASS_NAME";
    }
}
