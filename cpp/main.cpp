#include "clang/AST/ASTConsumer.h"
#include "clang/AST/ASTContext.h"
#include "clang/AST/Decl.h"
#include "clang/Analysis/CallGraph.h"
#include "clang/Frontend/CompilerInstance.h"
#include "clang/Frontend/FrontendAction.h"
#include "clang/Tooling/CommonOptionsParser.h"
#include "clang/Tooling/Tooling.h"
#include "llvm/ADT/PostOrderIterator.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/raw_ostream.h"
#include <iostream>
#include <set>
using namespace clang;
using namespace clang::tooling;
using namespace llvm;

static cl::OptionCategory MyToolCategory("cfg-cpp options");

class CallGraphConsumer : public ASTConsumer {
  CallGraph &CG;
  SourceManager &SM;
  std::set<std::pair<std::string, std::string>> edges;

public:
  CallGraphConsumer(CallGraph &CG, clang::SourceManager &SM) : CG(CG), SM(SM) {}
  void HandleTranslationUnit(ASTContext &Context) override {
    CG.addToCallGraph(Context.getTranslationUnitDecl());
    llvm::ReversePostOrderTraversal<const CallGraph *> RPOT(&CG);

    //TODO: also add to check what things are used in templates and added as dependencies
    for (const CallGraphNode *N : RPOT) {
      if (!N) {
        continue;
      }
      if (N == CG.getRoot()) {
        continue;
      }

      const Decl *D = N->getDecl();
      if (!D) {
        continue;
      }

      const NamedDecl *ND = dyn_cast<NamedDecl>(D);
      if (!ND) {
        continue;
      }
      
      //if i dont omit this the graph gets too big
      if (!SM.isInMainFile(ND->getLocation())) {
        continue;
      }

      std::string callerName = ND->getQualifiedNameAsString();
    
      if(callerName.find("std::") != std::string::npos){
        continue;
      }
      for (auto CI = N->begin(), CE = N->end(); CI != CE; ++CI) {
        if (!CI->Callee) {
          continue;
        }

        const Decl *CalleeDecl = CI->Callee->getDecl();
        if (!CalleeDecl) {
          continue;
        }

        const NamedDecl *CalleeND = dyn_cast<NamedDecl>(CalleeDecl);
        if (!CalleeND) {
          continue;
        }
        auto calleeName = CalleeND->getQualifiedNameAsString();
          //TODO: make configurable the things to ignore
        edges.insert({callerName, calleeName});
      }
    }
    llvm::outs() << "digraph callgraph {\n";
    for (const auto &edge : edges) {
      llvm::outs() << "  \"" << edge.first << "\" -> \"" << edge.second
                   << "\";\n";
    }
    llvm::outs() << "}\n";
  }
};

class CallGraphAction : public ASTFrontendAction {
  CallGraph &CG;

public:
  CallGraphAction(CallGraph &CG) : CG(CG) {}
  std::unique_ptr<ASTConsumer> CreateASTConsumer(CompilerInstance &CI,
                                                 StringRef file) override {
    return std::make_unique<CallGraphConsumer>(CG, CI.getSourceManager());
  }
};

class CallGraphActionFactory : public FrontendActionFactory {
  CallGraph &CG;

public:
  CallGraphActionFactory(CallGraph &CG) : CG(CG) {}
  std::unique_ptr<FrontendAction> create() override {
    return std::make_unique<CallGraphAction>(CG);
  }
};

int main(int argc, const char **argv) {
  auto ExpectedParser = CommonOptionsParser::create(argc, argv, MyToolCategory);
  if (!ExpectedParser) {
    llvm::errs() << ExpectedParser.takeError();
    return 1;
  }
  CommonOptionsParser &OptionsParser = ExpectedParser.get();
  ClangTool Tool(OptionsParser.getCompilations(),
                 OptionsParser.getSourcePathList());

  CallGraph CG;
  auto ActionFactory = std::make_unique<CallGraphActionFactory>(CG);
  Tool.run(ActionFactory.get());

  return 0;
}
